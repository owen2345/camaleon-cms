# custom class for site
Rails.application.config.to_prepare do
	CamaleonCms::Post.class_eval do
		include Plugins::LanguageSelectionPost::Models::Post

		def self.in_current_locale
		  joins(:metas).where("cama_metas.key = ? AND cama_metas.value LIKE ?", "available_languages", "%#{I18n.locale}%")
		end
	end
end
