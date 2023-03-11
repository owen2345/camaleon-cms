FactoryBot.define do
  factory :user, class: CamaManager.get_user_class_name do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    username { Faker::Internet.unique.user_name }
    password { '12345678' }
    password_confirmation { '12345678' }
    site { Cama::Site.first || build(:site) }
    
    factory :user_admin do
      role { 'admin' }
    end

    factory :user_shared do
      site_id { nil }
    end
  end
end