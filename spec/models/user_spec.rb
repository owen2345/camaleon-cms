# frozen_string_literal: true

require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::User, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[first_name last_name username]

  describe 'email' do
    it 'is lowercased' do
      user = described_class.create!(email: 'FOO@BAR.COM', username: 'test', password: 'test')

      expect(user.email).to eql('foo@bar.com')
    end
  end
end
