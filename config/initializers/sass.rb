module Sprockets
  # Processor engine class for the SASS/SCSS compiler. Depends on the `sass` gem.
  #
  # For more infomation see:
  #
  #   https://github.com/sass/sass
  #   https://github.com/rails/sass-rails
  #
  class SassProcessor
    module Functions
      # return them path (this prefix automatically the path with current theme location)
      # Sample: .container{ background: #ffffff url(asset_theme_path('img/patterns/pattern1.jpg')); }
      def asset_theme_path(path, options = {})
        asset_path(Autoload::Sass::Script::String.new("#{get_theme_prefix}/#{path.value}".gsub('//', '/')), options)
      end

      # return them path (this prefix automatically the path with current theme location)
      # Sample: .container{ background: #ffffff asset-theme-url('img/patterns/pattern1.jpg'); }
      def asset_theme_url(path, options = {})
        asset_url(Autoload::Sass::Script::String.new("#{get_theme_prefix}/#{path.value}".gsub('//', '/')), options)
      end

      # return them path (this prefix automatically the path with current theme location)
      def asset_plugin_path(path, options = {})
        asset_path(Autoload::Sass::Script::String.new("#{get_plugin_prefix}/#{path.value}"), options)
      end

      # return them path (this prefix automatically the path with current theme location)
      def asset_plugin_url(path, options = {})
        asset_url(Autoload::Sass::Script::String.new("#{get_plugin_prefix}/#{path.value}"), options)
      end

      private

      # get plugin asset prefix
      def get_plugin_prefix
        file = options[:filename]
        res = ''
        if file.include?('/plugins/')
          res = "plugins/#{file.split('/plugins/').last.split('/').first}/#{if file.include?('apps/plugins/')
                                                                              'assets/'
                                                                            end}"
        end
        res
      end

      # get theme asset prefix
      def get_theme_prefix
        file = options[:filename]
        res = ''
        if file.include?('/themes/')
          res = "themes/#{file.split('/themes/').last.split('/').first}/#{'assets/' if file.include?('apps/themes/')}"
        end
        res
      end
    end
  end
end
