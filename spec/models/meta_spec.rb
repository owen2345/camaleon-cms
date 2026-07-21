# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Meta, type: :model do
  describe 'value preservation' do
    it 'preserves angle brackets in Meta#value' do
      site = create(:site)
      meta = described_class.create!(objectid: site.id, object_class: 'Site', key: 'test_key', value: 'count < 10')
      expect(meta.reload.value).to eq('count < 10')
    end

    it 'preserves email addresses with angle brackets through set_option/get_option round-trip' do
      site = create(:site)
      site.set_option('email_from', 'My Name <myemail@domain.com>')
      fresh_site = CamaleonCms::Site.find(site.id)
      expect(fresh_site.get_option('email_from')).to eq('My Name <myemail@domain.com>')
    end

    it 'preserves angle brackets in JSON-serialized meta values' do
      site = create(:site)
      site.set_options(email_from: 'Admin <admin@test.com>', email_cc: 'Support <support@test.com>')
      fresh_site = CamaleonCms::Site.find(site.id)
      expect(fresh_site.get_option('email_from')).to eq('Admin <admin@test.com>')
      expect(fresh_site.get_option('email_cc')).to eq('Support <support@test.com>')
    end
  end
end
