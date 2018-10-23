source 'https://rubygems.org'

gem 'rails', ">= 4.2"

gem 'camaleon_cms', git: 'https://github.com/owen2345/camaleon-cms'
gem 'draper', '>= 3'# required for Rails 5+

### already dependency of main framework, only here to use latest git source
gem 'cama_contact_form', git: 'https://github.com/owen2345/cama_contact_form' 
gem 'cama_meta_tag', git: 'https://github.com/owen2345/camaleon-cms-seo'
### dependency end

gem 'camaleon_ecommerce', git: 'https://github.com/owen2345/camaleon-ecommerce'

gem 'camaleon_post_clone', git: 'https://github.com/owen2345/camaleon-post-clone'
gem 'camaleon_post_created_at', git: 'https://github.com/owen2345/camaleon_post_created_at'
gem 'camaleon_post_order', git: 'https://github.com/owen2345/camaleon-post-order-plugin'

gem 'cama_subscriber', git: 'https://github.com/owen2345/cama_subscriber'
gem 'cama_language_editor', git: 'https://github.com/owen2345/camaleon-cms-language-editor'
gem 'cama_external_menu', git: 'https://github.com/owen2345/cama_external_menu'
gem 'camaleon_cms_rating', git: 'https://github.com/aspirewit/camaleon_cms_rating'

gem 'camaleon_sitemap_customizer', git: 'https://github.com/brian-kephart/camaleon_sitemap_customizer'
gem 'camaleon_image_optimizer', git: 'https://github.com/brian-kephart/camaleon_image_optimizer'

# gem 'cama_tinymce_template', git: 'https://github.com/owen2345/Camaleon-Tinymce-Templates'
# gem 'cama_autocomplete', git: 'https://github.com/gaelfokou/cama_autocomplete.git'
# gem 'cama_image_lightbox', git: 'https://github.com/owen2345/CamaImageLightbox'
# gem 'camaleon_oauth', git: 'https://github.com/owen2345/camaleon_oauth'
# gem 'camaleon_download', git: 'https://github.com/max2320/camaleon-download'

require './lib/plugin_routes'; instance_eval(PluginRoutes.draw_gems) ### Camaleon CMS include all gems for plugins and themes
