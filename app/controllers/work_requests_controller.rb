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

    @time_slot_groups, @time_slots = build_time_slots(@work_requests)
    @shift_rows = build_shift_rows(@staff_members, @work_requests, @time_slots)
  end

def export
  # shiftアクションと同じデータを準備する
  shift

  rows = []

  # 1行目: 日付
  date_row = [""]

  @time_slot_groups.each do |date, slots|
    date_row << "#{date.month}/#{date.day}"

    # HTMLのcolspan相当として、残りのセルは空欄にする
    (slots.size - 1).times do
      date_row << ""
    end
  end

  rows << date_row

  # 2行目: 時刻
  rows << [
    "",
    *@time_slots.map { |slot| slot.strftime("%H:%M~") }
  ]

  # 3行目以降: スタッフ名と各時間帯の割当状況
  @shift_rows.each do |row|
    staff_name = row[:show_name] ? row[:staff].name : ""

    rows << [
      staff_name,
      *row[:cells].map { |cell| cell[:label] }
    ]
  end

  # 配列からCSV文字列を作成
  csv_data = rows.map do |row|
    row.map { |value| csv_escape(value) }.join(",")
  end.join("\r\n")

  # モーダルで入力されたファイル名を取得
  requested_filename = params[:filename].to_s.strip

  if requested_filename.empty?
    requested_filename =
      "シフト表_#{Time.current.strftime('%Y%m%d_%H%M')}"
  end

  # ファイル名に使用できない文字を置換
  safe_filename =
    requested_filename.gsub(/[\\\/:*?"<>|]/, "_")

  # 入力された末尾の.csvを削除
  safe_filename =
    safe_filename.sub(/(?:\.csv)+\z/i, "")

  # ファイル名が.csvだけだった場合などへの対策
  if safe_filename.empty?
    safe_filename =
      "シフト表_#{Time.current.strftime('%Y%m%d_%H%M')}"
  end

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
    return [ {}, [] ] if work_requests.empty?

    start_time = work_requests.map(&:starts_at).min.beginning_of_hour
    latest_end = work_requests.map(&:ends_at).max
    end_time = latest_end.beginning_of_hour
    end_time += 1.hour unless latest_end.min.zero? && latest_end.sec.zero?
    slots = (start_time...end_time).step(1.hour).to_a
    [ slots.group_by(&:to_date), slots ]
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
          occupying = track.select { |wr, _a| wr.starts_at <= slot && slot < wr.ends_at }

          if occupying.empty?
            { state: :empty, label: nil }
          else
            wr, a = occupying.first
            first_hour = wr.starts_at.beginning_of_hour == slot
            last_hour = slot + 1.hour >= wr.ends_at
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
