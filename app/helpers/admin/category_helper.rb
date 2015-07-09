#encoding: utf-8
module Admin::CategoryHelper

  def category_get_options_html(categories, level = 0)
    options = []
    categories.all.decorate.each do |category|
      options << [("—"*level) + category.the_title, category.id] unless @category.id == category.id
      children = category.children
      options += category_get_options_html(children, level + 1) if children.size > 0
    end
    options
  end

end