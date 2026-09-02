module NnRequestsSeed
  module_function

  def run(people)
    skills = people.fetch(:skills)
    staff_members = people.fetch(:staff_members)

    businesses = {}
    [
      [ :hotel, "[NN]みらいホテル", "NN担当者01", "03-0000-0101" ],
      [ :hall, "[NN]あおぞら会館", "NN担当者02", "03-0000-0102" ],
      [ :office, "[NN]中央オフィス", "NN担当者03", "03-0000-0103" ]
    ].each do |key, name, contact_name, contact_phone|
      businesses[key] = NnSeed.upsert_by(
        Business,
        { name: name },
        contact_name: contact_name,
        contact_phone: contact_phone,
        active: true
      )
    end

    request_specs = [
      [ :hotel, "NN客室清掃01", "NN_CLEANING", 20, 10, 12, 1, :open ],
      [ :hotel, "NN宴会場清掃01", "NN_CLEANING", 20, 13, 17, 3, :open ],
      [ :hall, "NN受付案内01", "NN_RECEPTION", 20, 10, 12, 2, :open ],
      [ :hall, "NN式典配膳01", "NN_SERVING", 20, 14, 18, 2, :confirmed ],
      [ :office, "NN調理補助01", "NN_KITCHEN", 20, 18, 20, 1, :open ],
      [ :hotel, "NN朝食配膳01", "NN_SERVING", 21, 7, 10, 2, :confirmed ],
      [ :hall, "NN会館受付01", "NN_RECEPTION", 21, 10, 14, 2, :draft ],
      [ :office, "NN厨房準備01", "NN_KITCHEN", 21, 13, 17, 2, :open ],
      [ :hotel, "NN共用部清掃01", "NN_CLEANING", 22, 9, 12, 2, :open ],
      [ :hall, "NN来場者受付01", "NN_RECEPTION", 22, 13, 16, 1, :open ],
      [ :office, "NN弁当準備01", "NN_KITCHEN", 22, 16, 20, 3, :open ],
      [ :hotel, "NN取消清掃01", "NN_CLEANING", 22, 10, 12, 1, :cancelled ]
    ]

    18.times do |index|
      day = 23 + (index % 2)
      start_hour = 9 + ((index * 2) % 8)
      end_hour = start_hour + [ 2, 3, 4 ][index % 3]
      skill_code = [ "NN_CLEANING", "NN_SERVING", "NN_RECEPTION", "NN_KITCHEN" ][index % 4]
      business_key = [ :hotel, :hall, :office ][index % 3]
      required_count = [ 1, 1, 2, 3 ][index % 4]
      status = [ :open, :open, :draft, :confirmed ][index % 4]

      request_specs << [
        business_key,
        format("NN定期業務%02d", index + 1),
        skill_code,
        day,
        start_hour,
        end_hour,
        required_count,
        status
      ]
    end

    requests = {}

    request_specs.each do |business_key, title, skill_code, day, start_hour, end_hour, required_count, status|
      requests[title] = NnSeed.upsert_by(
        WorkRequest,
        { business: businesses.fetch(business_key), title: title },
        required_skill: skills.fetch(skill_code),
        starts_at: Time.zone.local(2026, 8, day, start_hour),
        ends_at: Time.zone.local(2026, 8, day, end_hour),
        required_staff_count: required_count,
        status: status
      )
    end

    assignment_specs = {
      "NN客室清掃01" => [ [ "NN001", :draft ] ],
      "NN宴会場清掃01" => [ [ "NN001", :draft ], [ "NN005", :draft ] ],
      "NN式典配膳01" => [ [ "NN002", :confirmed ], [ "NN006", :confirmed ] ],
      "NN朝食配膳01" => [ [ "NN005", :confirmed ] ],
      "NN会館受付01" => [ [ "NN003", :draft ] ],
      "NN厨房準備01" => [ [ "NN004", :draft ] ],
      "NN共用部清掃01" => [ [ "NN007", :draft ], [ "NN008", :draft ] ],
      "NN来場者受付01" => [ [ "NN011", :draft ] ],
      "NN弁当準備01" => [ [ "NN004", :draft ], [ "NN008", :draft ] ]
    }

    assignment_specs.each do |title, assignments|
      assignments.each do |staff_key, status|
        NnSeed.upsert_by(
          Assignment,
          {
            work_request: requests.fetch(title),
            staff_member: staff_members.fetch(staff_key)
          },
          status: status
        )
      end
    end

    requests
  end
end
