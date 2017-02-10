module Cama
end
Rails.application.config.to_prepare do
  if PluginRoutes.static_system_info['user_model'].present?
    CamaleonCms::User = PluginRoutes.static_system_info['user_model'].constantize
    CamaleonCms::User.class_eval do
      include CamaleonCms::UserMethods
    end
  end
  Cama::User = CamaleonCms::User unless defined? Cama::User
end
Cama::Site = CamaleonCms::Site
Cama::Post = CamaleonCms::Post
Cama::Category = CamaleonCms::Category
Cama::PostTag = CamaleonCms::PostTag
Cama::PostType = CamaleonCms::PostType
Cama::TermTaxonomy = CamaleonCms::TermTaxonomy
Cama::TermRelationship = CamaleonCms::TermRelationship