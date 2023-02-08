# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

Rails.application.config.tinymce.install = :copy

# Add additional assets to the asset load path
Rails.application.config.assets.precompile += %w[camaleon_cms/*]
# Rails.application.config.assets.precompile += %w( themes/*/assets/* )

# This will precompile any assets, not just JavaScript (.js, .swf, .css, .scss)

sprockets_3 = !Sprockets.const_defined?(:BabelProcessor)
if sprockets_3
  Rails.application.config.assets.precompile << proc do |path|
    res = false
    dirname = File.dirname(path)
    if dirname.start_with?('plugins/') || dirname.start_with?('themes/')
      name = File.basename(path)
      content_type = begin
        MIME::Types.type_for(name).first.content_type
      rescue StandardError
        ''
      end
      if (path =~ /\.(css|js|svg|ttf|woff|eot|swf|pdf|png|jpg|gif)\z/ ||
        content_type.scan(%r{(javascript|image/|audio|video|font)}).any?) &&
         !name.start_with?('_') && !path.include?('/views/')
        res = true
      end
    end
    res
  end
end
