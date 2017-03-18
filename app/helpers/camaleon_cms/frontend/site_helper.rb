module CamaleonCms::Frontend::SiteHelper
  # return full current visited url
  def site_current_url
    request.original_url
  end

  # return current url visited as path
  # http://localhost:9001/category/cat-post-2  => /category/cat-post-2
  def site_current_path
    @_site_current_path ||= site_current_url.sub(cama_root_url(locale: nil), "/")
  end

  #**************** section is a? ****************#
  # check if current section visited is home page
  def is_home?
    @cama_visited_home.present?
  end

  # check if current section visited is for post
  def is_page?
    @cama_visited_post.present?
  end

  # check if current section visited is for post
  def is_profile?
    @cama_visited_profile.present?
  end

  # check if current section visited is for ajax
  def is_ajax?
    @cama_visited_ajax.present?
  end

  # check if current section visited is for search
  def is_search?
    @cama_visited_search.present?
  end

  # check if current section visited is for post type
  def is_post_type?
    @cama_visited_post_type.present?
  end

  # check if current section visited is for post tag
  def is_post_tag?
    @cama_visited_tag.present?
  end

  # check if current section visited is for category
  def is_category?
    @cama_visited_category.present?
  end
  
  # check if visited page is user profile (frontend)
  def is_profile?
    @cama_visited_profile == true
  end

  #**************** end section is a? ****************#

  # show custom assets added by plugins
  # show respond js and html5shiv
  # seo_attrs: Custom attributes for seo in Hash format
  # show_seo: (Boolean) control to append or not the seo attributes
  def the_head(seo_attrs = {}, show_seo = true)
    js = "<script>var ROOT_URL = '#{cama_root_url}'; var LANGUAGE = '#{I18n.locale}'; </script>".html_safe
    js += cama_draw_pre_asset_contents
    (csrf_meta_tag || "") + "\n" + display_meta_tags(cama_the_seo(seo_attrs)) + "\n" + js + "\n" + cama_draw_custom_assets
  end
end
