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
    @staff_members = StaffMember.available_for(work_request_id: @work_request.id)

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
  private

  def work_request_params
    params.expect(work_request: [ :notes ])
  end
end
