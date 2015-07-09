class CustomFieldDecorator < Draper::Decorator
  delegate_all

  def the_name
    object.name.start_with?('t(')? eval(object.name.sub('t(', 'I18n.t(')) : object.name
  end
  def the_description
    if object.description.start_with?('t(')
      eval(object.description.sub('t(', 'I18n.t('))
    elsif object.description.start_with?('eval(')
      eval(object.description)
    else
      object.description
    end
  end

  # cache identifier, the format is: [current-site-prefix]/[object-id]-[object-last_updated]/[current locale]
  # key: additional key for the model
  def cache_prefix(key = "")
    "#{h.current_site.cache_prefix}/cfield#{object.id}#{"/#{key}" if key.present?}"
  end

end
