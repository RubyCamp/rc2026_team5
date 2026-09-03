class WorkRequestsController < ApplicationController
  def index
    @work_requests = WorkRequest
      .includes(:business, :required_skill, assignments: :staff_member)
      .order(:starts_at)
  end

  def show
    @work_request = WorkRequest
      .includes(:business, :required_skill, assignments: :staff_member)
      .find(params[:id])
  end

  def edit
    @work_request = WorkRequest.find(params[:id])
  end

  def update
    @work_request = WorkRequest.update_details!(
      id: params[:id],
      attributes: work_request_params
    )

    redirect_to @work_request, notice: "勤務依頼の備考を更新しました。"
  rescue ActiveRecord::RecordInvalid => error
    raise unless error.record.is_a?(WorkRequest)

    @work_request = error.record
    render :edit, status: :unprocessable_content
  rescue ActiveRecord::RecordNotFound
    redirect_to work_requests_path, alert: "更新する勤務依頼が見つかりませんでした。"
  end

  # 仮割当取得用
  def draft
    logger.debug "画面が遷移しました"

    _requests_id = params[:id]   # 対象の勤務依頼IDを取得

    @assignments = Assignment.all
    @work_request = WorkRequest.find(_requests_id)  # 対象の勤務依頼を取得
    # @staff_member = StaffMember.all
    @staff_member = StaffMember.available_for(work_request_id: _requests_id)   # @StaffMemberに勤務可能なスタッフを取得
    _suffer = @work_request.staffing_shortage_count()

    logger.debug "最後のDBのID"

    # 10.times do |i|
    #   @assignments.unassign!(id:i+28)
    # end

    if !@work_request.staffing_sufficient?

      @staff_member.each do |staff|
        if !@work_request.staffing_sufficient?
          logger.debug "ループに入りました"
            # if !@assignments.time_conflict?(id: )
            @assignments.assign!(work_request_id: _requests_id, staff_member_id: staff.id)
          # end
        end
      end

      logger.debug "ifに入りましt"
      logger.debug "#{_suffer}人不足しています"

      # _suffer.times do |i|
      #   @assignments.assign!(work_request_id: _requests_id, staff_member_id: )
      # end

      logger.debug "終了"

    end

    # 追加処理後のDBの人数を読み直し、不足人数を画面へ渡す。
    @staffing_shortage_count = @work_request.reload.staffing_shortage_count

    # JavaScriptからTurbo-Frameヘッダー付きで呼ばれた場合だけ、
    # 割当欄のHTML（draft.html.erb）を返す。
    # ブラウザが通常のリンクとして開いた場合は、
    # draft.html.erbを単独ページとして表示せず、元のshowページへ戻す。
    respond_to do |format|
      # 人数不足時はポップアップを開いたままエラーを表示する。
      # 成功時はshowページへ戻して、ページの再表示と同時にポップアップを閉じる。
      format.turbo_stream do
        if @staffing_shortage_count.positive?
          render :draft
        else
          redirect_to @work_request, status: :see_other
        end
      end
      format.html do
        if request.headers["Turbo-Frame"].present?
          render :draft
        else
          redirect_to @work_request
        end
      end
    end
  end


  def shift
    @work_requests = WorkRequest.for_list
    @staff_members = StaffMember.order(:id)

    @date, @time_slots = build_time_slots(@work_requests)
    @shift_rows = build_shift_rows(@staff_members, @work_requests, @time_slots)
  end
  # def shift
  #   @staff_members = StaffMember
  #     .includes(:skills, :availabilities)
  #     .order(:id)
  #   @work_requests = WorkRequest
  #     .includes(:business, :required_skill, assignments: :staff_member)
  #     .order(:starts_at)
  #   @assignments = Assignment.all
  #   # @member = []
  #   # @work = []

  #   @graph_assignment = Array.new(@staff_members.size) { Array.new @work_requests.size, "-" }

  #   # @staff_1 = [ [] ]
  #   # @staff_2 = [ [] ]

  #   # @staff_members.size.times do ||
  #   #   @work_requests.size.times do ||
  #   #     @staff_1 << "-"
  #   #   end
  #   # end

  #   # ダミーデータ
  #   # @graph_assignment = [
  #   #   [ "-", "-", "-", "-", "-", "-" ],
  #   #   [ "-", "-", "-", "-", "-", "-" ],
  #   #   [ "-", "-", "-", "-", "-", "-" ],
  #   #   [ "-", "-", "-", "-", "-", "-" ],
  #   #   [ "-", "-", "-", "-", "-", "-" ]
  #   # ]

  #   @assignments.each do |data|
  #     logger.debug "仮割当情報を取得しました"
  #     logger.debug "#{data.work_request_id}"

  #     if data.status == "draft"
  #       @graph_assignment[data.staff_member_id - 1][data.work_request_id - 1] = "△"
  #     elsif data.status == "confirmed"
  #       @graph_assignment[data.staff_member_id - 1][data.work_request_id - 1] = "○"
  #     else
  #       # @graph_assignment[1][1] = "-"
  #     end
  #   end
  # end

  private

  def work_request_params
    params.expect(work_request: [ :notes ])
  end

  def build_time_slots(work_requests)
    return [ nil, [] ] if work_requests.empty?

    date = work_requests.map { |wr| wr.starts_at.to_date }.min
    start_hour = work_requests.map { |wr| wr.starts_at.hour }.min
    end_hour = work_requests.map { |wr| wr.ends_at.hour }.max
    slots = (start_hour...end_hour).map { |h| Time.zone.local(date.year, date.month, date.day, h) }
    [ date, slots ]
  end

  def build_shift_rows(staff_members, work_requests, time_slots)
    staff_members.flat_map do |staff|
      assignments = work_requests.flat_map do |wr|
        wr.assignments
          .select { |a| a.staff_member_id == staff.id }
          .map { |a| [ wr, a ] }
      end.sort_by { |wr, _a| wr.starts_at }

      tracks = split_into_tracks(assignments)

      tracks.each_with_index.map do |track, index|
        cells = time_slots.map do |slot|
          hour = slot.hour
          occupying = track.select { |wr, _a| wr.starts_at.hour <= hour && hour < wr.ends_at.hour }

          if occupying.empty?
            { state: :empty, label: nil }
          else
            wr, a = occupying.first
            first_hour = wr.starts_at.hour == hour
            last_hour = wr.ends_at.hour - 1 == hour
            mark = a.status == "confirmed" ? "○" : "△"
            label =
              if first_hour && last_hour
                "#{wr.business.name} [#{wr.title}] #{mark}"
              elsif first_hour
                "#{wr.business.name} [#{wr.title}]"
              elsif last_hour
                mark
              end
            { state: a.status.to_sym, label: label }
          end
        end

        { staff: staff, cells: cells, show_name: index.zero? }
      end
    end
  end

  # 時間が重ならない依頼同士を同じ「段」にまとめる
  def split_into_tracks(assignments)
    tracks = []

    assignments.each do |wr, a|
      track = tracks.find { |t| t.none? { |twr, _ta| overlap?(twr, wr) } }
      if track
        track << [ wr, a ]
      else
        tracks << [ [ wr, a ] ]
      end
    end

    tracks.presence || [ [] ]
  end

  def overlap?(wr1, wr2)
    wr1.starts_at < wr2.ends_at && wr2.starts_at < wr1.ends_at
  end
end
#   private

#   def work_request_params
#     params.expect(work_request: [ :notes ])
#   end
# end
