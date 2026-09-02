module NnSeed
  def self.upsert_by(model, identity, values = {})
    model.find_or_initialize_by(identity).tap do |record|
      record.assign_attributes(values)
      record.save!
    end
  end
end

namespace :nn do
  desc "NN確認用の人・依頼データを追加する"
  task seed: :environment do
    load(Rails.root.join("db/seeds/nn_people.rb"))
    load(Rails.root.join("db/seeds/nn_requests.rb"))
    people = NnPeopleSeed.run
    NnRequestsSeed.run(people)

    puts(
      "NN用データを投入しました" \
      "（スタッフ#{people.fetch(:staff_members).size}名、" \
      "スキル#{people.fetch(:skills).size}種類）"
    )
  end
end
