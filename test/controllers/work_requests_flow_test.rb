require "test_helper"

class WorkRequestsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @business = Business.create!(
      name: "テスト会館",
      contact_name: "担当者",
      contact_phone: "00-0000-0000"
    )
    skill = Skill.create!(code: "RECEPTION_#{SecureRandom.hex(4)}", name: "受付")
    @work_request = WorkRequest.create!(
      business: @business,
      required_skill: skill,
      title: "受付業務",
      starts_at: Time.zone.local(2026, 8, 20, 10),
      ends_at: Time.zone.local(2026, 8, 20, 12),
      required_staff_count: 1,
      notes: "集合場所は正面玄関"
    )
  end

  test "詳細画面に備考と編集リンクを表示する" do
    get work_request_path(@work_request)

    assert_response :success
    assert_select "h2", text: "備考"
    assert_select "p", text: "集合場所は正面玄関"
    assert_select "a[href=?]", edit_work_request_path(@work_request), text: "備考を編集"
  end

  test "備考だけを更新して詳細画面へ戻る" do
    assert_difference("ChangeEvent.count", 1) do
      patch work_request_path(@work_request), params: {
        work_request: {
          notes: "変更後は裏口へ集合",
          title: "この値は更新しない"
        }
      }
    end

    assert_redirected_to work_request_path(@work_request)
    assert_equal "変更後は裏口へ集合", @work_request.reload.notes
    assert_equal "受付業務", @work_request.title

    follow_redirect!
    assert_select ".alert-success", text: /勤務依頼の備考を更新しました/
    assert_select "p", text: "変更後は裏口へ集合"
  end

  test "備考編集画面を表示する" do
    get edit_work_request_path(@work_request)

    assert_response :success
    assert_select "h1", text: "勤務依頼の備考を編集"
    assert_select "form[action=?]", work_request_path(@work_request)
    assert_select "textarea[name=?]", "work_request[notes]", text: "集合場所は正面玄関"
  end
end
