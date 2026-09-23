# frozen_string_literal: true

RSpec.describe CamaleonCms::User, type: :model do
  describe 'email' do
    it 'is lowercased' do
      user = described_class.create!(email: 'FOO@BAR.COM', username: 'test', password: 'testpassword')

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

  # UserMethods set STATUS and ROLE in the block it runs on each model including it, which assigned them to the
  # concern again, so a second model including it warned that both were already initialized.
  describe 'the constants of CamaleonCms::UserMethods' do
    it 'are defined once, however many models include the concern' do
      stub_const('SpecSecondUser', Class.new(ActiveRecord::Base)) # rubocop:disable Rails/ApplicationRecord
      SpecSecondUser.table_name = described_class.table_name

      expect { SpecSecondUser.include(CamaleonCms::UserMethods) }.not_to output.to_stderr
      expect([SpecSecondUser::STATUS, SpecSecondUser::ROLE]).to eq([described_class::STATUS, described_class::ROLE])
    end
  end
end
