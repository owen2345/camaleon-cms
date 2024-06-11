# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::User, type: :model do
  describe 'email' do
    it 'is lowercased' do
      user = described_class.create!(email: 'FOO@BAR.COM', username: 'test', password: 'test')

      expect(user.email).to eql('foo@bar.com')
    end
  end
end
