class TutorialProfile
  ATTRIBUTES = %i[id name favorite message category published].freeze

  RECORDS = [
    [ 1, "ゆい", "ギター", "ライブを見ると元気になります", "music", true ],
    [ 2, "かい", "カレー", "辛いものを食べ歩くのが好きです", "food", true ],
    [ 3, "しおり", "温泉", "休日は小さな旅行に出かけます", "travel", true ],
    [ 4, "あおい", "ボードゲーム", "みんなで遊ぶゲームが好きです", "game", true ],
    [ 5, "なぎ", "バドミントン", "体を動かすと気分転換になります", "sports", true ],
    [ 6, "はる", "ドラム", "バンドのリズムを聴くのが好きです", "music", true ],
    [ 7, "まお", "パン", "新しいパン屋を探しています", "food", false ],
    [ 8, "たくみ", "パズルゲーム", "じっくり考えるゲームが好きです", "game", true ],
    [ 9, "いおり", "鉄道", "知らない駅で降りるのが好きです", "travel", true ],
    [ 10, "すず", "ランニング", "朝に走ると気持ちいいです", "sports", false ],
    [ 11, "くるみ", "プリン", "喫茶店めぐりが好きです", "food", true ],
    [ 12, "さくら", "ピアノ", "映画音楽をよく聴きます", "music", true ],
    [ 13, "うみ", "海辺", "景色の写真を撮るのが好きです", "travel", false ],
    [ 14, "おと", "卓球", "短いラリーでも集中します", "sports", true ],
    [ 15, "えま", "カードゲーム", "ルールを覚えて遊ぶのが楽しいです", "game", true ]
  ].map(&:freeze).freeze

  attr_reader(*ATTRIBUTES)

  def initialize(id:, name:, favorite:, message:, category:, published:)
    @id = id
    @name = name
    @favorite = favorite
    @message = message
    @category = category
    @published = published
  end

  def self.all
    RECORDS.map do |values|
      new(**ATTRIBUTES.zip(values).to_h)
    end
  end

  def self.published
    all.select(&:published)
  end

  def self.find(id)
    all.find { |profile| profile.id == id.to_i }
  end

  def matches?(query)
    normalized_query = query.to_s.strip.downcase
    return true if normalized_query.empty?

    [ name, favorite, message ].any? do |value|
      value.downcase.include?(normalized_query)
    end
  end
end
