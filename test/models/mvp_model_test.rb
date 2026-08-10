require "test_helper"

class MvpModelTest < ActiveSupport::TestCase
  setup do
    @business = Business.create!(
      name: "架空ホテル",
      contact_name: "担当者",
      contact_phone: "000-0000"
    )

    @skill = Skill.create!(
      code: "MVP_MODEL_TEST_CLEANING",
      name: "清掃"
    )

    @staff_member = StaffMember.create!(
      name: "教材スタッフ"
    )
  end

  test "staff member uses employment status instead of active flag" do
    assert_predicate @staff_member, :active?
    assert_not StaffMember.column_names.include?("active")
  end

  test "availability requires an increasing time range" do
    availability = @staff_member.availabilities.build(
      starts_at: Time.zone.local(2026, 8, 1, 10),
      ends_at: Time.zone.local(2026, 8, 1, 9)
    )

    assert_not availability.valid?
    assert availability.errors.added?(
      :ends_at,
      "は開始日時より後にしてください"
    )
  end

  test "work request requires a positive staff count" do
    request = @business.work_requests.build(
      required_skill: @skill,
      title: "午前清掃",
      starts_at: Time.zone.local(2026, 8, 1, 9),
      ends_at: Time.zone.local(2026, 8, 1, 12),
      required_staff_count: 0
    )

    assert_not request.valid?
  end

  test "same staff member cannot be assigned twice to one request" do
    request = @business.work_requests.create!(
      required_skill: @skill,
      title: "午前清掃",
      starts_at: Time.zone.local(2026, 8, 1, 9),
      ends_at: Time.zone.local(2026, 8, 1, 12),
      required_staff_count: 1
    )

    request.assignments.create!(
      staff_member: @staff_member
    )

    duplicate = request.assignments.build(
      staff_member: @staff_member
    )

    assert_not duplicate.valid?
  end
end
