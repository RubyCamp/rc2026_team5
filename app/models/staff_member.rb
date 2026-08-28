class StaffMember < ApplicationRecord
  has_many :availabilities, dependent: :destroy
  has_many :assignments, dependent: :restrict_with_error
  has_many :staff_skills, dependent: :destroy
  has_many :skills, through: :staff_skills

  enum :employment_status, { active: "active", inactive: "inactive" }, validate: true

  validates :name, presence: true

  def self.for_list
    includes(:skills, :availabilities).order(:name)
  end

  def self.for_assignment
    where(employment_status: :active).order(:name)
  end

  def self.available_for(work_request_id:)
    work_request = WorkRequest.find(work_request_id)
    assigned_staff_ids = Assignment.where(work_request_id:).select(:staff_member_id)

    skilled_for(work_request_id:)
      .merge(available_during(work_request_id:))
      .where.not(id: assigned_staff_ids)
      .distinct
      .order(:name)
  end

  def self.skilled_for(work_request_id:)
    work_request = WorkRequest.find(work_request_id)

    joins(:skills)
      .where(
        employment_status: :active,
        skills: { id: work_request.required_skill_id }
      )
      .distinct
      .order(:name)
  end

  def self.available_during(work_request_id:)
    work_request = WorkRequest.find(work_request_id)

    joins(:availabilities)
      .where(
        employment_status: :active,
        availabilities: { status: :available }
      )
      .where("availabilities.starts_at <= ?", work_request.starts_at)
      .where("availabilities.ends_at >= ?", work_request.ends_at)
      .distinct
      .order(:name)
  end

  def proficiency_label_for(skill_id:)
    staff_skill = staff_skills.find do |staff_skill|
      staff_skill.skill_id == skill_id
    end

    staff_skill&.proficiency_label
  end

  def confirmed_assignment_count(business_id: nil)
    relation = assignments.confirmed

    relation = relation.joins(:work_request)
                       .where(work_requests: { business_id: business_id }) if business_id

    relation.count
  end
end
