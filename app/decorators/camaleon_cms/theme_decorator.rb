class CamaleonCms::ThemeDecorator < CamaleonCms::TermTaxonomyDecorator
  delegate_all

  def the_id
    object.id
  end

  def the_settings_url
    args = h.cama_current_site_host_port({})
    h.cama_admin_settings_theme_url(args)
  end

  def the_settings_link
    return '' unless h.cama_current_user.present?
    attrs = {target: "_blank", style: "font-size:11px !important;cursor:pointer;"}.merge(attrs)
    h.link_to("&rarr; #{title || h.ct("edit", default: 'Edit')}".html_safe, the_settings_url, attrs)
  end
end
