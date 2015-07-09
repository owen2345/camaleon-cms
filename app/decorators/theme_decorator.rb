class ThemeDecorator < TermTaxonomyDecorator
  delegate_all

  def the_id
    object.id
  end

end
