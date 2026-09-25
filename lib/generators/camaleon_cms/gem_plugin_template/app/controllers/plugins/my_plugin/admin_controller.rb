module Plugins
  module PluginClass
    class AdminController < CamaleonCms::Apps::PluginsAdminController
      include Plugins::PluginClass::MainHelper
      # Confines submitted field_options to slugs the plugin actually registered (see save_settings).
      include CamaleonCms::Admin::CustomFieldsConcern
      def index; end

      # show settings form
      def settings; end

      # save values from settings form
      def save_settings
        @plugin.set_options(params[:options]) if params[:options].present? # save option values
        @plugin.set_metas(params[:metas]) if params[:metas].present? # save meta values
        # Save custom field values, confined to this plugin's own registered slugs (like core's admin
        # controllers) so a forged request cannot write values for slugs this plugin never defined.
        if params[:field_options].present?
          @plugin.set_field_values(cama_permitted_field_options('Plugin', field_groups: @plugin.get_field_groups))
        end
        redirect_to url_for(action: :settings), notice: 'Settings Saved Successfully'
      end
      # add custom methods below ....
    end
  end
end
