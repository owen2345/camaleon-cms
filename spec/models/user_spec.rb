require "rails_helper"

RSpec.describe "User", :type => :model do
  describe 'site' do
    it 'can be given' do
      site = CamaleonCms::Site.create!(name: 'test site')
      user = CamaleonCms::User.create!(site: site,
        username: 'test@test.com', email: 'test@test.com', password: 'test')
      
      user = CamaleonCms::User.find(user.id)
      user.site_id.should == site.id
      user.site.should == site
    end
    
    it 'is optional' do
      user = CamaleonCms::User.create!(
        username: 'test@test.com', email: 'test@test.com', password: 'test')
      
      user = CamaleonCms::User.find(user.id)
      user.site_id.should == -1
      user.site.should be_nil
    end
  end
end
