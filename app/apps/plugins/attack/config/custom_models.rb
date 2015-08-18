# custom class for site
Site.class_eval do
  has_many :attack, class_name: "Plugins::Attack::Models::Attack"
end