class WidgetDecorator < Draper::Decorator
  include CustomFieldsConcern
  delegate_all

end
