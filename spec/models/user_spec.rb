require "rails_helper"

RSpec.describe "User", :type => :model do
  it 'belongs to site' do
    site = CamaleonCms::Site.create!(name: 'test site')
    user = CamaleonCms::User.create!(site: site,
      username: 'test@test.com', email: 'test@test.com', password: 'test')
    
    user = CamaleonCms::User.find(user.id)
    user.site_id.should == site.id
    user.site.should == site
  end
end