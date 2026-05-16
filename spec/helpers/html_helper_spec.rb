# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_specs/i18n_value_translation_safety'

describe CamaleonCms::HtmlHelper do
  describe '#cama_print_i18n_value' do
    def render_i18n_value(value)
      helper.instance_eval { cama_print_i18n_value(value) }
    end

    before { I18n.backend.store_translations(:en, admin: { my_text: 'My Text' }) }

    it_behaves_like 'i18n value translation safety'
  end

  describe '#cama_draw_custom_assets' do
    it 'returns asset tags as renderable markup' do
      helper.cama_html_helpers_init
      allow(helper).to receive(:hooks_run)

      helper.cama_load_libraries('nav_menu')
      output = helper.cama_draw_custom_assets

      expect(output).to include('<script')
      expect(output).to include('<link')
      expect(output).not_to include('&lt;script')
      expect(output).not_to include('&lt;link')
    end
  end
end
