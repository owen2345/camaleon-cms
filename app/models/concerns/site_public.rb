module SitePublic
  extend ActiveSupport::Concern

  def get_post_type(key)
    post_types.where(slug: key).first
  end
  def get_template_name
    get_option('_theme', 'default')
  end
  def get_field(key)
    get_field_value(key)
  end


end