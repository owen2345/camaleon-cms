CamaleonCms::Site.class_eval do
  has_many :contact_forms, :class_name => "Plugins::ContactForm::Models::ContactForm", foreign_key: :site_id, dependent: :destroy
end