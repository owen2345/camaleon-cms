module CamaleonCms::MetasDecoratorMethods
  # return meta value translated for key in this model
  def the_meta(key)
    object.get_meta(key, "").translate(@_deco_locale)
  end

  # return option value translated for key in this model
  def the_option(key)
    object.get_option(key, "").translate(@_deco_locale)
  end
end
