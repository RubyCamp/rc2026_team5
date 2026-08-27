require "test_helper"

class TutorialsControllerTest < ActionDispatch::IntegrationTest
  test "プロフィール一覧を表示する" do
    get tutorial_path

    assert_response :success
    assert_select "h1", text: "Rails開発チュートリアル"
  end
end
