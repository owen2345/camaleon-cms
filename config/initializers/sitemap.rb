# These are the built-in defaults, so you don't need to specify them.
DynamicSitemaps.configure do |config|
  # config.path = Rails.root.join("public")
  # config.folder = "sitemaps" # This folder is emptied on each sitemap generation
  # config.index_file_name = "sitemap.xml"
  # config.always_generate_index = false # Makes sitemap.xml contain the sitemap
  # (e.g. site.xml) when only one sitemap
  #  file has been generated
  config.config_path = File.join($camaleon_engine_dir, "config", "sitemap.rb")
  # config.per_page = 50000
end