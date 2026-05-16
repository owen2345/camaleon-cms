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

  describe 'widgets association' do
    it 'fetches widgets by user_id' do
      user = create(:user)
      other_site = create(:site, slug: "other-site-#{SecureRandom.hex(3)}").decorate
      widget = CamaleonCms::Widget::Main.create!(
        taxonomy: CamaleonCms::Widget::Main.sti_name,
        name: 'User Widget',
        slug: "user-widget-#{SecureRandom.hex(4)}",
        parent_id: other_site.id,
        user_id: user.id
      )

      expect(user.widgets).to include(widget)
    end
  end
end
