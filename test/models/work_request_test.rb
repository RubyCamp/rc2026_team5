require "test_helper"

class WorkRequestTest < ActiveSupport::TestCase
  setup do
    business = Business.create!(
      name: "テスト事業者",
      contact_name: "担当者",
      contact_phone: "00-0000-0000"
    )

    skill = Skill.create!(
      code: "WORK_REQUEST_TEST_#{SecureRandom.hex(4)}",
      name: "テストスキル"
    )

    @later_request = WorkRequest.create!(
      business: business,
      required_skill: skill,
      title: "後の依頼",
      starts_at: Time.zone.local(2026, 8, 2, 10),
      ends_at: Time.zone.local(2026, 8, 2, 12),
      required_staff_count: 1,
      status: :open
    )

    @earlier_request = WorkRequest.create!(
      business: business,
      required_skill: skill,
      title: "先の依頼",
      starts_at: Time.zone.local(2026, 8, 1, 10),
      ends_at: Time.zone.local(2026, 8, 1, 12),
      required_staff_count: 1,
      status: :open
    )
  end

  test "for_listは開始日時順のRelationを返す" do
    result = WorkRequest.for_list.where(
      id: [ @later_request.id, @earlier_request.id ]
    )

    assert_kind_of ActiveRecord::Relation, result
    assert_equal [ @earlier_request, @later_request ], result.to_a
  end

  test "with_assignment_detailsはfindを続けられるRelationを返す" do
    result = WorkRequest.with_assignment_details

    assert_kind_of ActiveRecord::Relation, result
    assert_equal @earlier_request, result.find(@earlier_request.id)
  end

  test "with_staffing_shortageは割当が必要人数未満の依頼を返す" do
    staff_member = StaffMember.create!(
      name: "不足確認スタッフ",
      employment_status: :active
    )

    Assignment.assign!(
      work_request_id: @earlier_request.id,
      staff_member_id: staff_member.id
    )

    result = WorkRequest.with_staffing_shortage.where(
      id: [ @earlier_request.id, @later_request.id ]
    )

    assert_kind_of ActiveRecord::Relation, result
    assert_equal [ @later_request ], result.to_a
  end

  test "人数計算は現在存在する割当だけを対象にする" do
    staff_member = StaffMember.create!(
      name: "人数確認スタッフ",
      employment_status: :active
    )

    assignment = Assignment.assign!(
      work_request_id: @earlier_request.id,
      staff_member_id: staff_member.id
    )

    assert_equal 1, @earlier_request.active_assignment_count
    assert_equal 0, @earlier_request.staffing_shortage_count
    assert_predicate @earlier_request, :staffing_sufficient?

    Assignment.unassign!(id: assignment.id)

    assert_equal 0, @earlier_request.active_assignment_count
    assert_equal 1, @earlier_request.staffing_shortage_count
    assert_not_predicate @earlier_request, :staffing_sufficient?
  end

  test "不足人数は割当が必要人数を超えても0を返す" do
    2.times do |index|
      staff_member = StaffMember.create!(
        name: "超過スタッフ#{index}",
        employment_status: :active
      )

      Assignment.assign!(
        work_request_id: @earlier_request.id,
        staff_member_id: staff_member.id
      )
    end

    assert_equal 0, @earlier_request.staffing_shortage_count
  end

 test "register!は保存済みの勤務依頼を返す" do
  work_request = nil

  assert_difference("ChangeEvent.count", 1) do
    work_request = WorkRequest.register!(
      attributes: {
        business: @earlier_request.business,
        required_skill: @earlier_request.required_skill,
        title: "登録した依頼",
        starts_at: Time.zone.local(2026, 8, 3, 10),
        ends_at: Time.zone.local(2026, 8, 3, 12),
        required_staff_count: 2,
        status: :open
      }
    )
  end

  assert_predicate work_request, :persisted?
  assert_equal "登録した依頼", work_request.title

  assert_equal(
    "勤務依頼「登録した依頼」を登録しました",
    ChangeEvent.recent.first.summary
  )
end

  test "register!は保存失敗時にRecordInvalidを送出する" do
    assert_raises ActiveRecord::RecordInvalid do
      WorkRequest.register!(
        attributes: {
          title: ""
        }
      )
    end
  end

  test "update_details!は備考を更新して変更を記録する" do
    assert_difference("ChangeEvent.count", 1) do
      WorkRequest.update_details!(
        id: @earlier_request.id,
        attributes: { notes: "正面玄関へ集合" }
      )
    end

    assert_equal "正面玄関へ集合", @earlier_request.reload.notes
    assert_equal "勤務依頼「先の依頼」を更新しました", ChangeEvent.recent.first.summary
  end

  test "update_details!は実質的な変更がない場合に変更記録を作らない" do
    assert_no_difference("ChangeEvent.count") do
      WorkRequest.update_details!(
        id: @earlier_request.id,
        attributes: { title: @earlier_request.title }
      )
    end
  end
  test "変更記録の保存に失敗した場合は勤務依頼の登録も取り消す" do
    attributes = {
      business: @earlier_request.business,
      required_skill: @earlier_request.required_skill,
      title: "取り消される依頼",
      starts_at: Time.zone.local(2026, 8, 4, 10),
      ends_at: Time.zone.local(2026, 8, 4, 12),
      required_staff_count: 1,
      status: :open
    }

    with_change_event_record_failure do
      assert_no_difference("WorkRequest.count") do
        assert_raises ActiveRecord::RecordInvalid do
          WorkRequest.register!(attributes: attributes)
        end
      end
    end
  end

  test "cancel!は取消状態へ変更した勤務依頼を返す" do
    work_request = WorkRequest.cancel!(
      id: @earlier_request.id
    )

    assert_predicate work_request, :cancelled?
    assert_equal @earlier_request, work_request
  end

  test "remove!は割当のない下書きの勤務依頼を削除して返す" do
    @earlier_request.draft!

    work_request = WorkRequest.remove!(
      id: @earlier_request.id
    )

    assert_predicate work_request, :destroyed?

    assert_raises ActiveRecord::RecordNotFound do
      WorkRequest.find(@earlier_request.id)
    end
  end

  test "remove!は公開済みまたは割当のある勤務依頼を削除しない" do
    assert_raises ActiveRecord::RecordNotDestroyed do
      WorkRequest.remove!(id: @earlier_request.id)
    end

    @earlier_request.draft!

    staff_member = StaffMember.create!(
      name: "削除制限スタッフ",
      employment_status: :active
    )

    Assignment.assign!(
      work_request_id: @earlier_request.id,
      staff_member_id: staff_member.id
    )

    assert_raises ActiveRecord::RecordNotDestroyed do
      WorkRequest.remove!(id: @earlier_request.id)
    end

    assert_predicate @earlier_request.reload, :persisted?
  end

  test "存在しないIDはRecordNotFoundを送出する" do
    missing_id = WorkRequest.maximum(:id).to_i + 1

    assert_raises ActiveRecord::RecordNotFound do
      WorkRequest.update_details!(
        id: missing_id,
        attributes: {
          title: "更新"
        }
      )
    end

    assert_raises ActiveRecord::RecordNotFound do
      WorkRequest.cancel!(id: missing_id)
    end

    assert_raises ActiveRecord::RecordNotFound do
      WorkRequest.remove!(id: missing_id)
    end
  end
  private

def with_change_event_record_failure
  original = ChangeEvent.method(:record!)

  ChangeEvent.define_singleton_method(:record!) do |**|
    raise ActiveRecord::RecordInvalid.new(ChangeEvent.new)
  end

  yield
ensure
  ChangeEvent.define_singleton_method(:record!, original)
end
end
