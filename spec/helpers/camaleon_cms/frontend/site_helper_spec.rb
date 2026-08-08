require 'rails_helper'

# Regression audit M20: the frontend readers ignored the legacy @object / @cama_visited_* ivars, so a
# plugin front controller that set them (the 2.9.2 way) before rendering got nil-backed the_title /
# is_home? / SEO helpers. Core writes both CurrentRequest and the ivar, so stock flows never reach the
# fallback; these pin the restored read-side fallback.
RSpec.describe CamaleonCms::Frontend::SiteHelper, type: :helper do
  before do
    CurrentRequest.reset
    helper.singleton_class.include(CamaleonCms::Frontend::ContentSelectHelper)
  end

  after { CurrentRequest.reset }

  describe '#camaleon_frontend_visited_state' do
    it 'falls back to a plugin-set legacy @cama_visited_* ivar' do
      helper.instance_variable_set(:@cama_visited_home, true)

      expect(helper.send(:camaleon_frontend_visited_state, :frontend_visited_home)).to be(true)
    end

    it 'prefers CurrentRequest over the legacy ivar' do
      CurrentRequest.frontend_visited_home = 'current'
      helper.instance_variable_set(:@cama_visited_home, 'legacy')

      expect(helper.send(:camaleon_frontend_visited_state, :frontend_visited_home)).to eq('current')
    end
  end

  describe '#camaleon_frontend_object' do
    it 'falls back to a plugin-set @object ivar' do
      obj = instance_double(CamaleonCms::PostDecorator)
      helper.instance_variable_set(:@object, obj)

      expect(helper.send(:camaleon_frontend_object)).to eq(obj)
    end
  end
end
