# frozen_string_literal: true

require 'rails_helper'

describe 'Server restart confirmation modals', :js do
  init_site

  context 'when will_restart? is true' do
    before do
      allow(PluginRoutes).to receive(:will_restart?).and_return(true)
    end

    describe 'plugins page' do
      it 'shows restart modal when clicking activate/disable plugin' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/plugins"

        within '#tab_plugins_active' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Server Restart Required')
        expect(page).to have_content('multi-process mode')
      end

      it 'closes restart modal on cancel without navigating' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/plugins"

        within '#tab_plugins_active' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          click_button 'Cancel'
        end
        expect(page).to have_no_css('#server-restart-modal', visible: :visible)
        expect(page).to have_css('#table-plugins-list')
      end

      it 'closes restart modal on escape without navigating' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/plugins"

        within '#tab_plugins_active' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal.in', visible: :visible)
        find('body').send_keys(:escape)
        expect(page).to have_no_css('#server-restart-modal.in', visible: :visible)
        expect(page).to have_css('#table-plugins-list')
      end

      it 'triggers PluginRoutes.reload when clicking Confirm' do
        allow(PluginRoutes).to receive(:reload).and_call_original
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/plugins"

        within '#tab_plugins_active' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          find('[data-role="restart-confirm"]').click
        end

        expect(page).to have_current_path(%r{/admin/plugins}, url: true)
        expect(PluginRoutes).to have_received(:reload).exactly(:once) # rubocop:disable RSpec/MessageSpies
      end
    end

    describe 'themes page' do
      it 'shows restart modal when clicking select theme' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/appearances/themes"

        within '#themes_page' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Server Restart Required')
      end

      it 'closes restart modal on cancel without navigating' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/appearances/themes"

        within '#themes_page' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          click_button 'Cancel'
        end
        expect(page).to have_no_css('#server-restart-modal', visible: :visible)
        expect(page).to have_css('#themes_page')
      end

      it 'triggers PluginRoutes.reload when clicking Confirm' do
        allow(PluginRoutes).to receive(:reload).and_call_original
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/appearances/themes"

        within '#themes_page' do
          first('[data-restart-confirm]').click
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          find('[data-role="restart-confirm"]').click
        end

        expect(page).to have_current_path(%r{/admin/appearances/themes}, url: true)
        expect(PluginRoutes).to have_received(:reload).exactly(:once) # rubocop:disable RSpec/MessageSpies
      end
    end

    describe 'languages page' do
      it 'shows restart modal when clicking submit' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/languages"

        within '#languages_form' do
          click_button 'Submit'
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Server Restart Required')
      end

      it 'closes restart modal on cancel without submitting' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/languages"

        within '#languages_form' do
          click_button 'Submit'
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          click_button 'Cancel'
        end
        expect(page).to have_no_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Languages configuration')
      end

      it 'triggers PluginRoutes.reload when clicking Confirm' do
        allow(PluginRoutes).to receive(:reload).and_call_original
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/languages"

        within '#languages_form' do
          click_button 'Submit'
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          find('[data-role="restart-confirm"]').click
        end

        # After confirm, the form submits and page reloads
        expect(page).to have_current_path(%r{/admin/settings/languages}, url: true)
        expect(PluginRoutes).to have_received(:reload).exactly(:once) # rubocop:disable RSpec/MessageSpies
      end
    end

    describe 'post types page' do
      it 'shows restart modal when clicking submit on post type form' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        within '#post_type_form' do
          click_button 'Submit'
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Server Restart Required')
      end

      it 'closes restart modal on cancel without submitting' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        within '#post_type_form' do
          click_button 'Submit'
        end

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          click_button 'Cancel'
        end
        expect(page).to have_no_css('#server-restart-modal', visible: :visible)
        expect(page).to have_css('#post_type_form')
      end

      it 'shows restart modal when clicking delete post type' do
        admin_sign_in
        @site.post_types.create!(name: 'Deletable', slug: 'deletable', taxonomy: 'post_type')
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        first('[data-restart-confirm]').click

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Server Restart Required')
      end

      it 'triggers PluginRoutes.reload when clicking Confirm on delete' do
        admin_sign_in
        @site.post_types.create!(name: 'Deletable', slug: 'deletable-confirm', taxonomy: 'post_type')
        allow(PluginRoutes).to receive(:reload).and_call_original
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        first('[data-restart-confirm]').click

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          find('[data-role="restart-confirm"]').click
        end

        # After delete, the page reloads
        expect(page).to have_current_path(%r{/admin/settings/post_types}, url: true)
        expect(PluginRoutes).to have_received(:reload).exactly(:once) # rubocop:disable RSpec/MessageSpies
      end
    end

    describe 'sites page' do
      it 'shows restart modal when clicking submit on site form' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/sites/new"

        fill_in 'site_slug', with: 'testsite'
        fill_in 'site_name', with: 'Test Site'
        click_button 'Submit'

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        expect(page).to have_content('Server Restart Required')
      end

      it 'closes restart modal on cancel without submitting' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/sites/new"

        fill_in 'site_slug', with: 'testsite'
        fill_in 'site_name', with: 'Test Site'
        click_button 'Submit'

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          click_button 'Cancel'
        end
        expect(page).to have_no_css('#server-restart-modal', visible: :visible)
      end

      it 'triggers PluginRoutes.reload when clicking Confirm on new site' do
        allow(PluginRoutes).to receive(:reload).and_call_original
        allow(PluginRoutes).to receive(:trigger_server_restart_if_clustered).and_call_original
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/sites/new"

        fill_in 'site_slug', with: 'testsite-confirm'
        fill_in 'site_name', with: 'Test Site Confirm'
        click_button 'Submit'

        expect(page).to have_css('#server-restart-modal', visible: :visible)
        within '#server-restart-modal' do
          find('[data-role="restart-confirm"]').click
        end

        # After form submit, page navigates
        expect(page).to have_current_path(%r{/admin/settings/sites}, url: true)
        # reload is called multiple times by model callbacks, but the restart
        # is deferred via after_all_transactions_commit and only fires once
        expect(PluginRoutes).to have_received(:reload).at_least(:once) # rubocop:disable RSpec/MessageSpies
        expect(PluginRoutes).to have_received(:trigger_server_restart_if_clustered).exactly(:once) # rubocop:disable RSpec/MessageSpies
      end
    end
  end

  context 'when will_restart? is false' do
    before do
      allow(PluginRoutes).to receive(:will_restart?).and_return(false)
    end

    describe 'plugins page' do
      it 'does not render the restart modal' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/plugins"

        expect(page).to have_no_css('#server-restart-modal')
      end

      it 'uses standard confirm for plugin toggle' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/plugins"

        within '#tab_plugins_active' do
          expect(page).to have_no_css('[data-restart-confirm]')
        end
      end
    end

    describe 'themes page' do
      it 'does not render the restart modal' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/appearances/themes"

        expect(page).to have_no_css('#server-restart-modal')
      end

      it 'uses standard confirm for theme select' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/appearances/themes"

        within '#themes_page' do
          expect(page).to have_no_css('[data-restart-confirm]')
          expect(page).to have_css('[data-confirm]')
        end
      end
    end

    describe 'languages page' do
      it 'does not render the restart modal' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/languages"

        expect(page).to have_no_css('#server-restart-modal')
      end

      it 'has a standard submit button' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/languages"

        within '#languages_form' do
          expect(page).to have_no_css('[data-restart-submit]')
          expect(page).to have_css('button[type="submit"]')
        end
      end
    end

    describe 'post types page' do
      it 'does not render the restart modal' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        expect(page).to have_no_css('#server-restart-modal')
      end

      it 'has a standard submit button' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        within '#post_type_form' do
          expect(page).to have_no_css('[data-restart-submit]')
          expect(page).to have_css('button[type="submit"]')
        end
      end

      it 'uses standard confirm for delete' do
        admin_sign_in
        @site.post_types.create!(name: 'Deletable', slug: 'deletable-false', taxonomy: 'post_type')
        visit "#{cama_root_relative_path}/admin/settings/post_types"

        expect(page).to have_no_css('[data-restart-confirm]')
        expect(page).to have_css('[data-confirm]')
      end
    end

    describe 'sites page' do
      it 'does not render the restart modal on new site form' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/sites/new"

        expect(page).to have_no_css('#server-restart-modal')
      end

      it 'has a standard submit button on new site form' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/sites/new"

        expect(page).to have_no_css('[data-restart-submit]')
        expect(page).to have_css('button[type="submit"]')
      end

      it 'does not render the restart modal on sites index' do
        admin_sign_in
        visit "#{cama_root_relative_path}/admin/settings/sites"

        expect(page).to have_no_css('#server-restart-modal')
      end
    end
  end
end
