# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

Rails.application.config.tinymce.install = :compile

# Add additional assets to the asset load path
Rails.application.config.assets.precompile += %w( camaleon_cms/* )
Rails.application.config.assets.precompile += %w( themes/*/assets/* )

# This will precompile any assets, not just JavaScript (.js, .coffee, .swf, .css, .scss)
Rails.application.config.assets.precompile << Proc.new { |path|
  name = File.basename(path)
  content_type = MIME::Types.type_for(name).first.content_type rescue ""
  res = false
  if (path =~ /\.(css|js|svg|ttf|woff|eot|swf|pdf)\z/ || content_type.scan(/(javascript|image\/|audio|video|font)/).any?) && !name.start_with?("_") && !path.include?('/views/')
    res = true
  end
  res
}
