module CamaleonCms
  module SessionRuntimeConcern
    extend ActiveSupport::Concern

    def auth_session_error
      redirect_to cama_root_path
    end

    unless ApplicationController.method_defined?(:current_user)
      def current_user
        cama_current_user
      end
    end
  end
end
