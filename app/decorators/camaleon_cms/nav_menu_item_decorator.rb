module CamaleonCms
  class NavMenuItemDecorator < Draper::Decorator
    include CamaleonCms::CustomFieldsConcern
    delegate_all
  end
end
