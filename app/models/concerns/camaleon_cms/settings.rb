# frozen_string_literal: true

module CamaleonCms
  # A post's and a post type's settings: the options they read their configuration from, written through the
  # option writers. The keys are listed where Post includes this module, and in PostType::DEFAULT_OPTIONS.
  module Settings
    # set or update a setting
    def set_setting(key, value)
      set_option(key, value)
    end

    # assign multiple settings, in one options write
    def set_settings(settings = {})
      set_options(settings)
      settings
    end
  end
end
