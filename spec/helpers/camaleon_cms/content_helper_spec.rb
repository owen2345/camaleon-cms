# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::ContentHelper do
  let(:content_helper) do
    Class.new do
      include CamaleonCms::ContentHelper
    end.new
  end

  describe 'CurrentRequest-backed helper state' do
    it 'stores content buffers in CurrentRequest' do
      content_helper.cama_content_init
      content_helper.cama_content_prepend('<div>before</div>')
      content_helper.cama_content_append('<div>after</div>')

      state = CurrentRequest.content_helper_state
      expect(state[:before_content]).to eq(['<div>before</div>'])
      expect(state[:after_content]).to eq(['<div>after</div>'])
      expect(content_helper.cama_content_before_draw).to eq('<div>before</div>')
      expect(content_helper.cama_content_after_draw).to eq('<div>after</div>')
    end

    it 'reinitializes buffers after CurrentRequest.reset' do
      content_helper.cama_content_init
      content_helper.cama_content_prepend('<div>before</div>')
      CurrentRequest.reset

      expect(content_helper.cama_content_before_draw).to eq('')
      expect(content_helper.cama_content_after_draw).to eq('')
    end
  end
end
