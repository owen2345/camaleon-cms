#encoding: utf-8
module CamaleonCms::Admin::CategoryHelper

  # build an array multiple with category items prefixed with - for each level
  # categories: collection of categories
  # level: internal iterator control
  # attrs: (Hash) extra params
  #   max_level: (Integer) permit to stop iteration in certain level
  #   until_cats: (Array of cat ids) permit to stop iteration if current iteration is in this array
  #   exclude_cats: (Array of cat ids) exclude this categories from the list
  def cama_category_get_options_html(categories, level = 0, attrs = {})
    attrs = {max_level: 1000, until_cats:[], exclude_cats: []}.merge(attrs)
    options = []
    categories.all.decorate.each do |category|
      next if attrs[:exclude_cats].include?(category.id)
      options << [("—"*level) + category.the_title, category.id]
      children = attrs[:max_level] < level ? [] : category.children
      children = [] if attrs[:until_cats].include?(category.id)
      options += cama_category_get_options_html(children, level + 1, attrs) if children.size > 0
    end
    options
  end

end
