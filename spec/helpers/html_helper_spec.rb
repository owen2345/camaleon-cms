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
end
