namespace :camaleon_cms do
  desc 'Generate thumbnails for uploaded files'
  task generate_thumbnails: :environment do
    include CamaleonCms::CamaleonHelper
    include CamaleonCms::HooksHelper
    include CamaleonCms::SiteHelper
    include CamaleonCms::PluginsHelper
    include CamaleonCms::ThemeHelper
    include CamaleonCms::UploaderHelper
    include Rails.application.routes.url_helpers
    $current_site = CamaleonCms::Site.find(ENV['site_id'].to_i)
    cama_uploader_init_connection
    @fog_connection_bucket_dir.files.all.each do |file|
      puts file.inspect
      cama_uploader_generate_thumbnail(file.key, file.key, "")
    end
  end
end
