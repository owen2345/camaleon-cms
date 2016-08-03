#encoding: utf-8
module CamaleonCms::Admin::PostTypeHelper

  #taxonomy -> (categories || post_tags)
  def post_type_html_inputs(post_type, taxonomy="categories", name ="categories", type="checkbox", values=[], class_cat="categorychecklist" , required = false)
    categories = post_type.send(taxonomy)
    categories = categories.eager_load(:children, :post_type_parent, :parent) if taxonomy == "categories" || taxonomy == "children"
    post_type_taxonomy_html_(categories,taxonomy, name, type, values, class_cat, required)
  end

  def post_type_status(status, color="default")
    html = "<span class='label label-#{color} label-form'>#{status}</span>"

  end

  #taxonomies ->  (categories || post_tags)
  def post_type_list_taxonomy(taxonomies, color="primary")
    html = ""
    taxonomies.decorate.each do |f|
      html += "<a class='cama_ajax_request' href='#{cama_admin_post_type_taxonomy_posts_path(@post_type.id, f.taxonomy, f.id)}'><span class='label label-#{color} label-form'>#{f.the_title}</span></a> "
    end
    return html
  end


  # sort array of posts to build post's tree
  # skip_non_parent_posts: don't include post's where root post doesn't exist
  # internal control for recursive items
  def cama_hierarchy_post_list(posts_list, parent_id = nil, skip_non_parent_posts = false)
    res = []
    @_cama_hierarchy_post_list_no_parent ||= posts_list.clone
    posts_list.each do |element|
      if element.post_parent.to_s == parent_id.to_s
        res << element
        @_cama_hierarchy_post_list_no_parent.delete_item(element)
        res += cama_hierarchy_post_list(posts_list, element.id)
      end
    end

    if !parent_id.present? && !skip_non_parent_posts
      @_cama_hierarchy_post_list_no_parent.each do |element|
        element.show_title_with_parent = true
        res << element
        res += cama_hierarchy_post_list(posts_list, element.id)
      end
    end
    res
  end

  private

  def post_type_taxonomy_html_(categories, taxonomy="categories", name="categories", type="checkbox", values=[], class_cat="", required = false)
    return "#{t('camaleon_cms.admin.post_type.message.no_created_html', taxonomy: (taxonomy == "categories")? t('camaleon_cms.admin.table.categories') : t('camaleon_cms.admin.table.tags') )}" if categories.count < 1
    html = "<ul class='#{class_cat}'>"
    categories.decorate.each do |f|
      html += "<li>"
      html +=  "<label class='class_slug' data-post_link_edit='#{f.the_edit_url}'> "
      html +=  "<input data-error-place='#validation_error_list_#{name}' type='#{type}' name='#{name}[]' #{ values.to_i.include?(f.id) ? "checked" : ""} value='#{f.id}' class = '#{ "required" if required }' />"
      html += "#{f.the_title} </label> "
      html +=  post_type_html_inputs(f, "children" , name, type, values, "children")  if f.children.present?
      html += "</li>"
    end

    html += "</ul><div id='validation_error_list_#{name}'></div>"
    return html
  end
end
