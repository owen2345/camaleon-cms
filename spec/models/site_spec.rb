# frozen_string_literal: true

require 'rails_helper'
require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::Site, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]

  describe 'check metas relationships' do
    let!(:site) { create(:site).decorate }

    it 'creates metas with correct `object_class`' do
      front_cache_elements = site.metas.where(key: 'front_cache_elements').first

      expect(front_cache_elements.object_class).to eql('Site')
    end

    it 'does not leak metas from other object classes sharing the same object id' do
      # This guards against associations that only scope by objectid and ignore object_class.
      CamaleonCms::Meta.create!(
        objectid: site.id,
        object_class: 'UserRole',
        key: "leak-check-#{SecureRandom.hex(4)}",
        value: 'x'
      )

      expect(site.metas.where(object_class: 'UserRole')).to be_empty
    end
  end
end
