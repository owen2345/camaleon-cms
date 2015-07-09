#encoding: utf-8
module Admin::PostTypeHelper

  #taxonomy -> (categories || post_tags)
  def post_type_html_inputs(post_type, taxonomy="categories", name ="categories", type="checkbox", values=[], class_cat="categorychecklist" , required = false)
    categories = post_type.send(taxonomy)
    categories = categories.eager_load(:children) if taxonomy == "categories" || taxonomy == "children"
    post_type_taxonomy_html_(categories,taxonomy, name, type, values, class_cat, required)
  end

  def post_type_status(status, color="default")
    html = "<span class='label label-#{color} label-form'>#{status}</span>"

  end

  #taxonomies ->  (categories || post_tags)
  def post_type_list_taxonomy(taxonomies, color="primary")
    html = ""
    taxonomies.decorate.each do |f|
      html += "<a href='#{admin_post_type_taxonomy_posts_path(@post_type.id, f.taxonomy, f.id)}'><span class='label label-#{color} label-form'>#{f.the_title}</span></a> "
    end
    return html
  end

  private

  def post_type_taxonomy_html_(categories, taxonomy="categories", name="categories", type="checkbox", values=[], class_cat="", required = false)
    return "#{t('admin.post_type.message.no_created_html', taxonomy: (taxonomy == "categories")? t('admin.table.categories') : t('admin.table.tags') )}" if categories.count < 1
    html = "<ul class='#{class_cat}'>"
    categories.decorate.each do |f|
      html += "<li>"
      html +=  "<label class='class_slug' data-post_link_edit='#{f.the_edit_url}'> "
      html +=  "<input type='#{type}' name='#{name}[]' #{ values.to_i.include?(f.id) ? "checked" : ""} value='#{f.id}' class = '#{ "required" if required }' />"
      html += "#{f.the_title} </label> "
      html +=  post_type_html_inputs(f, "children" , name, type, values, "children")  if f.children.present?
      html += "</li>"
    end

    html += "</ul>"
    return html
  end
end