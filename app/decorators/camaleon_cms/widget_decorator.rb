class CamaleonCms::WidgetDecorator < Draper::Decorator
  include CamaleonCms::CustomFieldsConcern
  delegate_all
end
