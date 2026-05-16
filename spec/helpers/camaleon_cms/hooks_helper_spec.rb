# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::HooksHelper do
  let(:hooks_helper) do
    Class.new do
      include CamaleonCms::HooksHelper
    end.new
  end

  describe 'CurrentRequest-backed helper state' do
    it 'stores the skip list in CurrentRequest' do
      hooks_helper.hook_skip('skip_me')

      expect(CurrentRequest.hooks_helper_state[:hooks_skip]).to eq(['skip_me'])
    end

    it 'starts with an empty skip list after CurrentRequest.reset' do
      hooks_helper.hook_skip('skip_me')
      CurrentRequest.reset

      expect(hooks_helper.send(:hook_skip_list)).to eq([])
    end
  end
end
