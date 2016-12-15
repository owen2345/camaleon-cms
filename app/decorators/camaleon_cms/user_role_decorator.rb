class CamaleonCms::UserRoleDecorator < CamaleonCms::ApplicationDecorator
  include CamaleonCms::CustomFieldsConcern
  delegate_all

  def the_title
    object.name.to_s.translate(get_locale)
  end

  def the_content
    object.description.to_s.translate(get_locale)
  end
end
