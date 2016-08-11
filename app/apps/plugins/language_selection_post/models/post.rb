module Plugins::LanguageSelectionPost::Models::Post
  def available_languages
  	metas.where(key: "available_languages").first.try(:value) ||
    I18n.locale.to_s
  end
end
