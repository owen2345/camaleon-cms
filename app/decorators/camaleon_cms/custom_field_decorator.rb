class CamaleonCms::CustomFieldDecorator < Draper::Decorator
  delegate_all

  def the_name
    h.cama_print_i18n_value(object.name)
  end

  def the_description
    h.cama_print_i18n_value(object.description)
  end
end
