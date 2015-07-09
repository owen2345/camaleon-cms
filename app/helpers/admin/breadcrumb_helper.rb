module Admin::BreadcrumbHelper
# draw html admin breadcrumb
  def admin_breadcrumb_draw
    res = []
    @_admin_breadcrumb.each_with_index do |item, index|
      if @_admin_breadcrumb.size == (index+1) #last menu
        res << "<li class='active'>#{item[0]}</li>"
      else
        res << "<li><a href='#{item[1]}'>#{item[0]}</a></li>"
      end
    end
    res.join("")
  end

  def admin_title_draw
    res = []
    @_admin_breadcrumb.each_with_index do |item, index|
      res << item[0]
    end
    res.join(" &raquo; ")
  end

  # add breadcrumb item at the end
  # label => label of the link
  # url: url for the link
  def admin_breadcrumb_add(label, url = "")
    @_admin_breadcrumb << [label, url]
  end
end