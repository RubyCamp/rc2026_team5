require "test_helper"

class TutorialProfileTest < ActiveSupport::TestCase
  test "allは固定のプロフィール15件を返す" do
    profiles = TutorialProfile.all

    assert_equal 15, profiles.size
    assert_equal((1..15).to_a, profiles.map(&:id))
  end

  test "publishedは公開プロフィールだけを返す" do
    profiles = TutorialProfile.published

    assert_equal 12, profiles.size
    assert_empty profiles.map(&:id) & [ 7, 10, 13 ]
    assert profiles.all?(&:published)
  end

  test "findは文字列のIDでもプロフィールを返す" do
    profile = TutorialProfile.find("1")

    assert_equal "ゆい", profile.name
    assert_equal "ギター", profile.favorite
  end

  test "findは存在しないIDにnilを返す" do
    assert_nil TutorialProfile.find("999")
  end

  test "matches?は名前と好きなものとひとことを部分一致で検索する" do
    profile = TutorialProfile.find(1)

    assert profile.matches?("ゆい")
    assert profile.matches?("ギター")
    assert profile.matches?("ライブ")
    assert_not profile.matches?("カレー")
  end
end
