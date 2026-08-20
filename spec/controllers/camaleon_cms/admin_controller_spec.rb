# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::AdminController do
  # Regression M19, controller half: the insert methods preserving store identity is pinned in
  # menus_helper_spec, but the alias itself lives in admin_init_actions — master shipped
  # `@_admin_menus = {}` (a separate hash), which no-oped the `@_admin_menus.delete('key')` idiom.
  describe '#admin_init_actions (regression M19)' do
    let(:controller) { described_class.new }
    let(:site) { CamaleonCms::Site.first.decorate }

    before { allow(controller).to receive(:current_site).and_return(site) }

    it 'aliases @_admin_menus onto the live CurrentRequest admin menu store' do
      controller.send(:admin_init_actions)

      expect(controller.instance_variable_get(:@_admin_menus)).to equal(CurrentRequest.admin_menu_items)
    end

    it 'lets a delete through @_admin_menus reach the store admin_menu_draw reads' do
      controller.send(:admin_init_actions)
      controller.send(:admin_menu_add_menu, 'comments', { icon: 'c', title: 'Comments' })

      controller.instance_variable_get(:@_admin_menus).delete('comments')

      expect(CurrentRequest.admin_menu_items).not_to have_key('comments')
    end
  end
end
