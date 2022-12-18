module Themes::Default::DefaultHelper
  def self.included(klass)
    klass.helper_method [:get_taxonomy] rescue ""
  end

  def theme_default_load_app

  end

  def theme_default_settings(theme)

  end

  def get_taxonomy(taxonomies = {}, rel = '')
    list = []
    if taxonomies.present?
      taxonomies.each do |taxonomy|
        list << "<a href='#{taxonomy.the_url}' rel='#{rel}'>#{taxonomy.the_title}</a>"
      end
    end
    list.join(', ')
  end

  def theme_default_on_install(theme)
    theme.add_field({"name"=>"Footer message", "slug"=>"footer"},{field_key: "editor", default_value: 'Copyright &copy; 2015 - Camaleon CMS. All rights reservated.'})
  end

end
