class Assignment < ApplicationRecord
  belongs_to :work_request
  belongs_to :staff_member

  enum :status, { draft: "draft", confirmed: "confirmed" }, validate: true

  validates :staff_member_id,
            uniqueness: {
              scope: :work_request_id
            }

  def self.for_work_request(work_request_id:)
    includes(:staff_member).where(work_request_id:).order(:created_at)
  end

  def self.draft_for_confirmation
    includes(
      { staff_member: { staff_skills: :skill } },
      work_request: [ :business, :required_skill ]
    )
      .where(status: :draft)
      .order("work_requests.starts_at", :created_at)
  end

  def self.overlapping_for(id:)
    assignment = find(id)
    work_request = assignment.work_request
    return none if work_request.cancelled?

    joins(:work_request)
      .where(staff_member_id: assignment.staff_member_id)
      .where.not(id: id)
      .where.not(work_requests: { status: :cancelled })
      .where(
        "work_requests.starts_at < :target_ends_at " \
        "AND work_requests.ends_at > :target_starts_at",
        target_ends_at: work_request.ends_at,
        target_starts_at: work_request.starts_at
      )
      .order("work_requests.starts_at", :created_at)
  end

  def self.time_conflict?(id:)
    overlapping_for(id: id).exists?
  end

  def self.assign!(work_request_id:, staff_member_id:)
  transaction do
    create!(
      work_request_id: work_request_id,
      staff_member_id: staff_member_id,
      status: :draft
    ).tap do |assignment|
      ChangeEvent.record!(
        target_type: :assignment,
        target_id: assignment.id,
        action_type: :assigned,
        summary: "#{assignment.staff_member.name}さんを" \
                 "勤務依頼「#{assignment.work_request.title}」へ" \
                 "仮割当しました"
      )
    end
  end
end

def self.confirm!(id:)
  transaction do
    find(id).tap do |assignment|
      assignment.confirmed!

      next unless assignment.saved_changes.except("updated_at").any?

      ChangeEvent.record!(
        target_type: :assignment,
        target_id: assignment.id,
        action_type: :confirmed,
        summary: "#{assignment.staff_member.name}さんの" \
                 "勤務依頼「#{assignment.work_request.title}」への" \
                 "割当を確定しました"
      )
    end
  end
end

def self.unassign!(id:)
  transaction do
    find(id).tap do |assignment|
      target_id = assignment.id
      staff_name = assignment.staff_member.name
      work_request_title = assignment.work_request.title

      assignment.destroy!

      ChangeEvent.record!(
        target_type: :assignment,
        target_id: target_id,
        action_type: :unassigned,
        summary: "#{staff_name}さんの" \
                 "勤務依頼「#{work_request_title}」への" \
                 "割当を解除しました"
      )
    end
  end
end
end
