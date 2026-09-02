module NnPeopleSeed
  module_function

  def run
    skills = {}

    [
      [ "NN_CLEANING", "[NN]清掃" ],
      [ "NN_SERVING", "[NN]配膳" ],
      [ "NN_RECEPTION", "[NN]受付" ],
      [ "NN_KITCHEN", "[NN]調理補助" ]
    ].each do |code, name|
      skills[code] = NnSeed.upsert_by(
        Skill,
        { code: code },
        name: name,
        active: true
      )
    end

    profiles = [
      [ "NN001", "[NN]佐々木 あおい", :active, [ [ "NN_CLEANING", "経験あり" ] ] ],
      [ "NN002", "[NN]田中 れん", :active, [ [ "NN_SERVING", "熟練" ] ] ],
      [ "NN003", "[NN]山本 みどり", :active, [ [ "NN_RECEPTION", "経験あり" ] ] ],
      [ "NN004", "[NN]伊藤 たくみ", :active, [ [ "NN_KITCHEN", "研修中" ] ] ],
      [ "NN005", "[NN]渡辺 なお", :active, [ [ "NN_CLEANING", "熟練" ], [ "NN_SERVING", "経験あり" ] ] ],
      [ "NN006", "[NN]中村 ひかり", :active, [ [ "NN_SERVING", "経験あり" ], [ "NN_RECEPTION", "研修中" ] ] ],
      [ "NN007", "[NN]小林 そうた", :active, [ [ "NN_CLEANING", "研修中" ], [ "NN_RECEPTION", "経験あり" ] ] ],
      [ "NN008", "[NN]加藤 ゆう", :active, [ [ "NN_KITCHEN", "経験あり" ], [ "NN_CLEANING", "経験あり" ] ] ],
      [ "NN009", "[NN]吉田 まい", :active, [ [ "NN_CLEANING", "未経験" ] ] ],
      [ "NN010", "[NN]山田 けい", :active, [ [ "NN_CLEANING", "経験あり" ], [ "NN_SERVING", "研修中" ] ] ],
      [ "NN011", "[NN]井上 りく", :active, [ [ "NN_RECEPTION", "熟練" ], [ "NN_KITCHEN", "経験あり" ] ] ],
      [ "NN012", "[NN]木村 こうじ", :inactive, [ [ "NN_CLEANING", "熟練" ] ] ]
    ]

    staff_members = {}

    profiles.each do |key, name, employment_status, staff_skills|
      staff_member = NnSeed.upsert_by(
        StaffMember,
        { name: name },
        employment_status: employment_status
      )
      staff_members[key] = staff_member

      staff_skills.each do |skill_code, proficiency_label|
        NnSeed.upsert_by(
          StaffSkill,
          { staff_member: staff_member, skill: skills.fetch(skill_code) },
          proficiency_label: proficiency_label
        )
      end
    end

    profiles.each_with_index do |(key, _name, employment_status, _staff_skills), index|
      staff_member = staff_members.fetch(key)
      days = employment_status == :active ? (20..24).to_a : [ 20 ]

      days.each do |day|
        start_hour, end_hour = case index % 4
        when 0 then [ 9, 18 ]
        when 1 then [ 10, 15 ]
        when 2 then [ 13, 20 ]
        else [ 9, 12 ]
        end

        status =
          (key == "NN006" && day == 22) ||
          (key == "NN009" && day == 21) ? :unavailable : :available

        NnSeed.upsert_by(
          Availability,
          {
            staff_member: staff_member,
            starts_at: Time.zone.local(2026, 8, day, start_hour)
          },
          ends_at: Time.zone.local(2026, 8, day, end_hour),
          status: status
        )
      end
    end

    { skills: skills, staff_members: staff_members }
  end
end
