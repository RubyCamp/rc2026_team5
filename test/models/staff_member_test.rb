require "test_helper"

class StaffMemberTest < ActiveSupport::TestCase
  setup do
    @active_later = StaffMember.create!(
      name: "Charlie",
      employment_status: :active
    )

    @active_earlier = StaffMember.create!(
      name: "Alice",
      employment_status: :active
    )

    @inactive = StaffMember.create!(
      name: "Bob",
      employment_status: :inactive
    )
  end

  test "for_listは在籍状態を問わず氏名順のRelationを返す" do
    result = StaffMember.for_list.where(
      id: [
        @active_later.id,
        @active_earlier.id,
        @inactive.id
      ]
    )

    assert_kind_of ActiveRecord::Relation, result

    assert_equal(
      [ @active_earlier, @inactive, @active_later ],
      result.to_a
    )
  end

  test "for_assignmentは在籍中のスタッフだけを氏名順で返す" do
    result = StaffMember.for_assignment.where(
      id: [
        @active_later.id,
        @active_earlier.id,
        @inactive.id
      ]
    )

    assert_kind_of ActiveRecord::Relation, result
    assert_equal [ @active_earlier, @active_later ], result.to_a
  end

  test "available_forは条件を満たす未割当スタッフだけを返す" do
    business = Business.create!(
      name: "候補テスト事業者",
      contact_name: "担当者",
      contact_phone: "00-0000-0000"
    )

    required_skill = Skill.create!(
      code: "CANDIDATE_#{SecureRandom.hex(4)}",
      name: "候補テストスキル"
    )

    other_skill = Skill.create!(
      code: "OTHER_#{SecureRandom.hex(4)}",
      name: "別スキル"
    )

    work_request = WorkRequest.create!(
      business: business,
      required_skill: required_skill,
      title: "候補テスト依頼",
      starts_at: Time.zone.local(2026, 8, 20, 10),
      ends_at: Time.zone.local(2026, 8, 20, 12),
      required_staff_count: 2,
      status: :open
    )

    candidate = create_candidate(
      name: "候補 一郎",
      skill: required_skill,
      work_request: work_request,
      status: :available
    )

    create_candidate(
      name: "別技能 二郎",
      skill: other_skill,
      work_request: work_request,
      status: :available
    )

    create_candidate(
      name: "勤務不可 三郎",
      skill: required_skill,
      work_request: work_request,
      status: :unavailable
    )

    create_candidate(
      name: "退職 四郎",
      skill: required_skill,
      work_request: work_request,
      status: :available,
      employment_status: :inactive
    )

    assigned = create_candidate(
      name: "割当済 五郎",
      skill: required_skill,
      work_request: work_request,
      status: :available
    )

    Assignment.assign!(
      work_request_id: work_request.id,
      staff_member_id: assigned.id
    )

    result = StaffMember.available_for(
      work_request_id: work_request.id
    )

    assert_kind_of ActiveRecord::Relation, result
    assert_equal [ candidate ], result.to_a
  end

  test "available_forは存在しない勤務依頼でRecordNotFoundを送出する" do
    missing_id = WorkRequest.maximum(:id).to_i + 1

    assert_raises ActiveRecord::RecordNotFound do
      StaffMember.available_for(work_request_id: missing_id)
    end
  end

  test "skilled_forは在籍中で必要スキルを持つスタッフを返す" do
    work_request, required_skill = create_work_request

    skilled = create_candidate(
      name: "技能適合",
      skill: required_skill,
      work_request: work_request,
      status: :unavailable
    )

    other_skill = Skill.create!(
      code: "OTHER_#{SecureRandom.hex(4)}",
      name: "別スキル"
    )

    create_candidate(
      name: "技能不適合",
      skill: other_skill,
      work_request: work_request,
      status: :available
    )

    result = StaffMember.skilled_for(
      work_request_id: work_request.id
    )

    assert_equal [ skilled ], result.to_a
  end

  test "available_duringは依頼時間全体に勤務可能な在籍スタッフを返す" do
    work_request, required_skill = create_work_request

    available = create_candidate(
      name: "時間適合",
      skill: required_skill,
      work_request: work_request,
      status: :available
    )

    unavailable = create_candidate(
      name: "勤務不可",
      skill: required_skill,
      work_request: work_request,
      status: :unavailable
    )

    result = StaffMember
      .available_during(work_request_id: work_request.id)
      .where(id: [ available.id, unavailable.id ])

    assert_equal [ available ], result.to_a
  end

  test "割当解除後は同じスタッフがavailable_forの候補へ戻る" do
    work_request, required_skill = create_work_request

    staff_member = create_candidate(
      name: "再割当候補",
      skill: required_skill,
      work_request: work_request,
      status: :available
    )

    assignment = Assignment.assign!(
      work_request_id: work_request.id,
      staff_member_id: staff_member.id
    )

    assert_empty StaffMember.available_for(
      work_request_id: work_request.id
    )

    Assignment.unassign!(id: assignment.id)

    result = StaffMember.available_for(
      work_request_id: work_request.id
    )

    assert_equal [ staff_member ], result.to_a
  end

  test "proficiency_label_forは該当スキルの習熟度ラベルを返し未保有ならnilを返す" do
    skill = Skill.create!(
      code: "PROFICIENCY_#{SecureRandom.hex(4)}",
      name: "習熟度テストスキル"
    )
    other_skill = Skill.create!(
      code: "PROFICIENCY_OTHER_#{SecureRandom.hex(4)}",
      name: "未保有スキル"
    )
    StaffSkill.create!(
      staff_member: @active_later,
      skill: skill,
      proficiency_label: "指導可能"
    )

    assert_equal "指導可能", @active_later.proficiency_label_for(
      skill_id: skill.id
    )
    assert_nil @active_later.proficiency_label_for(skill_id: other_skill.id)
  end

  test "confirmed_assignment_countはconfirmedだけを数え事業者で絞り込める" do
    first_business = Business.create!(
      name: "件数テスト事業者1",
      contact_name: "担当者",
      contact_phone: "00-0000-0001"
    )
    second_business = Business.create!(
      name: "件数テスト事業者2",
      contact_name: "担当者",
      contact_phone: "00-0000-0002"
    )

    first_confirmed = create_counted_assignment(
      business: first_business,
      staff_member: @active_later
    )
    Assignment.confirm!(id: first_confirmed.id)

    second_confirmed = create_counted_assignment(
      business: second_business,
      staff_member: @active_later
    )
    Assignment.confirm!(id: second_confirmed.id)

    draft = create_counted_assignment(
      business: first_business,
      staff_member: @active_later
    )

    assert_equal 2, @active_later.confirmed_assignment_count
    assert_equal 1, @active_later.confirmed_assignment_count(
      business_id: first_business.id
    )
    assert_equal 1, @active_later.confirmed_assignment_count(
      business_id: second_business.id
    )
    refute_predicate draft, :confirmed?
  end

  test "draft_for_confirmationは確認画面用の関連をpreloadする" do
    business = Business.create!(
      name: "preloadテスト事業者",
      contact_name: "担当者",
      contact_phone: "00-0000-0003"
    )
    skill = Skill.create!(
      code: "PRELOAD_#{SecureRandom.hex(4)}",
      name: "preloadテストスキル"
    )
    work_request = WorkRequest.create!(
      business: business,
      required_skill: skill,
      title: "preloadテスト依頼",
      starts_at: Time.zone.local(2026, 8, 20, 10),
      ends_at: Time.zone.local(2026, 8, 20, 12),
      required_staff_count: 1,
      status: :open
    )
    StaffSkill.create!(
      staff_member: @active_later,
      skill: skill,
      proficiency_label: "対応可能"
    )
    assignment = Assignment.assign!(
      work_request_id: work_request.id,
      staff_member_id: @active_later.id
    )

    result = Assignment.draft_for_confirmation.where(id: assignment.id).to_a
    loaded = result.first

    assert_predicate loaded.association(:staff_member), :loaded?
    assert_predicate loaded.staff_member.association(:staff_skills), :loaded?
    assert_predicate loaded.staff_member.staff_skills.first.association(:skill), :loaded?
    assert_predicate loaded.association(:work_request), :loaded?
    assert_predicate loaded.work_request.association(:business), :loaded?
    assert_predicate loaded.work_request.association(:required_skill), :loaded?
  end

  private

  def create_work_request
    business = Business.create!(
      name: "条件別候補事業者",
      contact_name: "担当者",
      contact_phone: "00-0000-0000"
    )

    skill = Skill.create!(
      code: "FILTER_#{SecureRandom.hex(4)}",
      name: "条件別候補スキル"
    )

    work_request = WorkRequest.create!(
      business: business,
      required_skill: skill,
      title: "条件別候補依頼",
      starts_at: Time.zone.local(2026, 8, 20, 10),
      ends_at: Time.zone.local(2026, 8, 20, 12),
      required_staff_count: 1,
      status: :open
    )

    [ work_request, skill ]
  end

  def create_counted_assignment(business:, staff_member:)
    skill = Skill.create!(
      code: "COUNT_#{SecureRandom.hex(4)}",
      name: "件数テストスキル"
    )
    work_request = WorkRequest.create!(
      business: business,
      required_skill: skill,
      title: "件数テスト依頼",
      starts_at: Time.zone.local(2026, 8, 20, 10),
      ends_at: Time.zone.local(2026, 8, 20, 12),
      required_staff_count: 1,
      status: :open
    )

    Assignment.assign!(
      work_request_id: work_request.id,
      staff_member_id: staff_member.id
    )
  end

  def create_candidate(
    name:,
    skill:,
    work_request:,
    status:,
    employment_status: :active
  )
    staff_member = StaffMember.create!(
      name: name,
      employment_status: employment_status
    )

    StaffSkill.create!(
      staff_member: staff_member,
      skill: skill,
      proficiency_label: "対応可能"
    )

    Availability.create!(
      staff_member: staff_member,
      starts_at: work_request.starts_at,
      ends_at: work_request.ends_at,
      status: status
    )

    staff_member
  end
end
