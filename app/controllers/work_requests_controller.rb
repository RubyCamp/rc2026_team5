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
    # 必要人数を超えて候補者を取得・仮割当しないよう、不足人数分に制限する。
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
    @assignments = Assignment.all
    # @member = []
    # @work = []

    @graph_assignment = Array.new(@staff_members.size) { Array.new @work_requests.size, "-" }

    # @staff_1 = [ [] ]
    # @staff_2 = [ [] ]

    # @staff_members.size.times do ||
    #   @work_requests.size.times do ||
    #     @staff_1 << "-"
    #   end
    # end

    # ダミーデータ
    # @graph_assignment = [
    #   [ "-", "-", "-", "-", "-", "-" ],
    #   [ "-", "-", "-", "-", "-", "-" ],
    #   [ "-", "-", "-", "-", "-", "-" ],
    #   [ "-", "-", "-", "-", "-", "-" ],
    #   [ "-", "-", "-", "-", "-", "-" ]
    # ]

    @assignments.each do |data|
      logger.debug "仮割当情報を取得しました"
      logger.debug "#{data.work_request_id}"

      if data.status == "draft"
        @graph_assignment[data.staff_member_id - 1][data.work_request_id - 1] = "△"
      elsif data.status == "confirmed"
        @graph_assignment[data.staff_member_id - 1][data.work_request_id - 1] = "○"
      else
        # @graph_assignment[1][1] = "-"
      end
    end
  end

  # --- ADD --- 2026/09/02 sou シフト表のエクスポートを追加  --- end ---
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

    # スタッフIDと配列上の行番号を対応させる
    staff_indexes = {}

    staff_members.each_with_index do |staff_member, index|
      staff_indexes[staff_member.id] = index
    end

    # 勤務依頼IDと配列上の列番号を対応させる
    work_request_indexes = {}

    work_requests.each_with_index do |work_request, index|
      work_request_indexes[work_request.id] = index
    end

    # 割当状況を表に反映する
    Assignment.find_each do |assignment|
      staff_index = staff_indexes[assignment.staff_member_id]
      work_request_index =
        work_request_indexes[assignment.work_request_id]

      next if staff_index.nil? || work_request_index.nil?

      graph_assignment[staff_index][work_request_index] =
        case assignment.status
        when "draft"
          "△"
        when "confirmed"
          "○"
        else
          "-"
        end
    end

    rows = []

    # CSVの1行目
    rows << [
      "",
      *work_requests.map do |work_request|
        I18n.l(work_request.starts_at, format: :short)
      end
    ]

    # CSVの2行目以降
    staff_members.each_with_index do |staff_member, index|
      rows << [
        staff_member.name,
        *graph_assignment[index]
      ]
    end

    # 配列をCSV形式の文字列へ変換する
    csv_data = rows.map do |row|
      row.map do |value|
        csv_escape(value)
      end.join(",")
    end.join("\r\n")

    send_data(
      "\uFEFF#{csv_data}",
      filename: "シフト表_#{Time.current.strftime('%Y%m%d_%H%M')}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
    )
  end

  def csv_escape(value)
  text = value.to_s

  # Excelで数式として解釈されることを防ぐ
  if text.match?(/\A[=+@\t\r]/)
    text = "'#{text}"
  end

  # 値に含まれるダブルクォートを二重にする
  text = text.gsub('"', '""')

  # セル全体をダブルクォートで囲む
  %(#{text})
  end


  private

  def work_request_params
    params.expect(work_request: [ :notes ])
  end
end
