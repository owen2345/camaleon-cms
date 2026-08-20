module CamaleonCms
  class ThemeDecorator < CamaleonCms::TermTaxonomyDecorator
    delegate_all

    def the_id
      object.id
    end

    def the_settings_url
      args = h.cama_current_site_host_port({})
      h.cama_admin_settings_theme_url(args)
    end

    def the_settings_link(title = nil, attrs = {})
      return '' if h.cama_current_user.blank?

      attrs = { target: '_blank', style: 'font-size:11px !important;cursor:pointer;' }.merge(attrs)
      h.link_to(h.safe_join(['→ ', title || h.ct('edit', default: 'Edit')]), the_settings_url, attrs)
    end
  end
end
