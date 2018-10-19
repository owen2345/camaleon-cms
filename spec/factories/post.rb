FactoryBot.define do
  factory :post, class: CamaleonCms::Post do
    title { Faker::Job.title }
    sequence(:slug) { |n| "post#{n}" }
    content { Faker::Lorem.sentence }
    published_at { Time.current }

    transient do
      site { nil }
    end
    
    post_type { association :post_type, site: site || create(:site) }
    owner { association :user, site: site }
    
    factory :pending_post do
      status { 'pending' }
    end

    factory :draft_post do
      status { 'draft' }
    end
    
    factory :children_post do
      parent { post }
    end
    
    factory :private_post do
      visibility { 'private' }
      visibility_value { owner.role }
    end
    
    factory :password_post do
      visibility { 'password' }
      visibility_value { '12345' }
    end

    factory :featured_post do
      is_feature { true }
    end

    # data_options {} # all attrs in Post#set_setting()
    # data_metas {thumb: <String thumb full url>, layout: <String layout name>, template: <String template name>, summary: <Text summary>, has_comments: <0|1>}
  end
end
