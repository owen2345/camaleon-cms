module Plugins
  module PluginClass
    class FrontController < CamaleonCms::Apps::PluginsFrontController
      include Plugins::PluginClass::MainHelper
      def index
        # actions for frontend module
      end

      # add custom methods below
    end
  end
end
