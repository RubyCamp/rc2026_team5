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
          if !@assignment.time_conflict?
            @assignments.assign!(work_request_id: _requests_id, staff_member_id: staff.id)
          end
        end
      end

      logger.debug "ifに入りましt"
      logger.debug "#{_suffer}人不足しています"

      # _suffer.times do |i|
      #   @assignments.assign!(work_request_id: _requests_id, staff_member_id: )
      # end

      logger.debug "終了"

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
  private

  def work_request_params
    params.expect(work_request: [ :notes ])
  end
end
