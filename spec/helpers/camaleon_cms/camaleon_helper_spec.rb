# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::CamaleonHelper, type: :helper do
  describe '#cama_is_admin_request?' do
    it 'returns true when the admin compatibility helper exposes a frontend locale' do
      helper.define_singleton_method(:cama_get_i18n_frontend) { :es }

      expect(helper.cama_is_admin_request?).to be(true)
    end

    it 'returns false when the helper is running outside the admin compatibility context' do
      expect(helper.cama_is_admin_request?).to be(false)
    end
  end
end
