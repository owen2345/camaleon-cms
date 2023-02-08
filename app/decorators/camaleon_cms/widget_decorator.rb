module CamaleonCms
  class WidgetDecorator < Draper::Decorator
    include CamaleonCms::CustomFieldsConcern
    delegate_all
  end
end
