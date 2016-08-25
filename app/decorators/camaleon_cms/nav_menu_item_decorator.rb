class CamaleonCms::NavMenuItemDecorator < Draper::Decorator
  include CamaleonCms::CustomFieldsConcern
  delegate_all
end
