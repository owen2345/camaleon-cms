#encoding: utf-8
module CamaleonCms::Admin::CategoryHelper

  # build an array multiple with category items prefixed with - for each level
  # categories: collection of categories
  # level: internal iterator control
  def cama_category_get_options_html(categories, level = 0)
    options = []
    categories.all.decorate.each do |category|
      options << [("—"*level) + category.the_title, category.id] unless @category.id == category.id
      children = category.children
      options += cama_category_get_options_html(children, level + 1) if children.size > 0
    end
    options
  end

end
