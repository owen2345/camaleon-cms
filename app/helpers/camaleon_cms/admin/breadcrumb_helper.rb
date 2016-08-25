module CamaleonCms::Admin::BreadcrumbHelper
  # draw the title for the admin admin panel according the breadcrumb
  def cama_admin_title_draw
    res = [t("camaleon_cms.admin.sidebar_top.admin_panel")]
    @breadcrumbs.reverse.slice(0, 2).reverse.each{|b| res << b.name }
    res.join(" &raquo; ")
  end

  # add breadcrumb item at the end
  # label => label of the link
  # url: url for the link
  # DEPRECATED
  def admin_breadcrumb_add(label, url = "")
  end
end
