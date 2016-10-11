require 'rails_helper'

RSpec.describe CamaleonCms::User, type: :model do
  describe 'email' do
    it 'is lowercased' do
      user = CamaleonCms::User.create!(
        email: 'FOO@BAR.COM',
        username: 'test', password: 'test')
      user.email.should == 'foo@bar.com'
    end
  end
end
