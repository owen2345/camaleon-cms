module CamaleonCms
  class PostUniqValidator < ActiveModel::Validator
    def validate(record)
      unless record.draft?
        slug_array = record.slug.to_s.translations_array
        ptype = record.post_type
        if ptype.present? # only for posts that belongs to a post type model
          posts = ptype.site.posts
                       .where("(#{slug_array.map {|s| "#{CamaleonCms::Post.table_name}.slug LIKE '%-->#{s}<!--%'"}.join(" OR ")} ) OR #{CamaleonCms::Post.table_name}.slug = ?",  record.slug)
                       .where.not(id: record.id)
                       .where.not(status: [:draft, :draft_child, :trash])
          if posts.size > 0
            if slug_array.size > 1
              record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{posts.pluck(:slug).map{|slug| record.slug.to_s.translations.map{|lng, r_slug| "#{r_slug} (#{lng})" if slug.translations_array.include?(r_slug) }.join(",") }.join(",").split(",").uniq.clean_empty.join(", ")} "
            else
              record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{record.slug.to_s} "
            end
          end

          # avoid recursive page parent
          record.errors[:base] << I18n.t('camaleon_cms.admin.post.message.recursive_hierarchy', default: 'Parent Post Recursive') if record.post_parent.present? && ptype.manage_hierarchy? && record.parents.cama_pluck(:id).include?(record.id)
        else
          # validation for other classes
        end
      end
    end
  end
end
