# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Site, type: :model do
  describe 'check metas relationships' do
    let!(:site) { create(:site).decorate }

    it 'creates metas with correct `object_class`' do
      front_cache_elements = site.metas.where(key: 'front_cache_elements').first

      expect(front_cache_elements.object_class).to eql('Site')
    end
  end
end
