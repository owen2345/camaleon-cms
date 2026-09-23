# frozen_string_literal: true

module CamaleonCms
  # A post's and a post type's settings: the options they read their configuration from, written through the
  # option writers. The keys are listed where Post includes this module, and in PostType::DEFAULT_OPTIONS.
  module Settings
    # set or update a setting
    def set_setting(key, value)
      set_option(key, value)
    end

    # assign multiple settings, in one options write; request parameters are written from a copy, since
    # set_options permits the parameters it is given, which would leave the caller's permitted
    def set_settings(settings = {})
      set_options(settings.is_a?(ActionController::Parameters) ? settings.deep_dup : settings)
      settings
    end
  end
end
