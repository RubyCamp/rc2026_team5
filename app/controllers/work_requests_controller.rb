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
    @work_request = WorkRequest.find(params[:id])

    @staff_members = StaffMember
      .available_for(work_request_id: @work_request.id)
      .limit(@work_request.staffing_shortage_count)

    @staff_members.each do |staff|
      break if @work_request.reload.staffing_sufficient?

      Assignment.assign!(
        work_request_id: @work_request.id,
        staff_member_id: staff.id
      )
    end

    # 追加処理後のDBの人数を読み直し、不足人数を画面へ渡す。
    @staffing_shortage_count = @work_request.reload.staffing_shortage_count

    respond_to do |format|
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

  # 仮割当全解除
  def unassign_all
    @work_request = WorkRequest.find(params[:id])

    @work_request.assignments.each do |assignment|
      Assignment.unassign!(id: assignment.id)
    end

    redirect_to work_request_path(@work_request)
  end

  def destroy_assignment
    @work_request = WorkRequest.find(params[:work_request_id])
    assignment = @work_request.assignments.find(params[:id])

    Assignment.unassign!(id: assignment.id)

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to @work_request, notice: "#{assignment.staff_member.name}さんの仮割当を解除しました。"
      end
    end
  end

  def shift
    @staff_members = StaffMember
      .includes(:skills, :availabilities)
      .order(:id)

    @work_requests = WorkRequest
      .includes(:business, :required_skill, assignments: :staff_member)
      .order(:starts_at)

    @date, @time_slots = build_time_slots(@work_requests)
    @shift_rows = build_shift_rows(@staff_members, @work_requests, @time_slots)
  end

  def export
    staff_members = StaffMember
      .includes(:skills, :availabilities)
      .order(:id)
      .to_a

    work_requests = WorkRequest
      .includes(:business, :required_skill, assignments: :staff_member)
      .order(:starts_at)
      .to_a

    graph_assignment = Array.new(staff_members.size) do
      Array.new(work_requests.size, "-")
    end

    staff_indexes = {}
    staff_members.each_with_index do |staff_member, index|
      staff_indexes[staff_member.id] = index
    end

    work_request_indexes = {}
    work_requests.each_with_index do |work_request, index|
      work_request_indexes[work_request.id] = index
    end

    Assignment.find_each do |assignment|
      staff_index = staff_indexes[assignment.staff_member_id]
      work_request_index = work_request_indexes[assignment.work_request_id]

      next if staff_index.nil? || work_request_index.nil?

      graph_assignment[staff_index][work_request_index] =
        case assignment.status
        when "draft" then "△"
        when "confirmed" then "○"
        else "-"
        end
    end

    rows = []
    rows << [ "", *work_requests.map { |wr| I18n.l(wr.starts_at, format: :short) } ]

    staff_members.each_with_index do |staff_member, index|
      rows << [ staff_member.name, *graph_assignment[index] ]
    end

    csv_data = rows.map { |row| row.map { |v| csv_escape(v) }.join(",") }.join("\r\n")

    requested_filename = params[:filename].to_s.strip

    if requested_filename.empty?
      requested_filename =
        "シフト表_#{Time.current.strftime('%Y%m%d_%H%M')}"
    end

    # ファイル名として使用できない文字を「_」へ置換
    safe_filename = requested_filename.gsub(/[\\\/:*?"<>|]/, "_")

    # 利用者が.csvまで入力しても二重に付かないようにする
    safe_filename = safe_filename.delete_suffix(".csv")

    send_data(
      "\uFEFF#{csv_data}",
      filename: "#{safe_filename}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
    )
  end

  def csv_escape(value)
    text = value.to_s
    text = "'#{text}" if text.match?(/\A[=+@\t\r]/)
    text = text.gsub('"', '""')
    %(#{text})
  end

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
