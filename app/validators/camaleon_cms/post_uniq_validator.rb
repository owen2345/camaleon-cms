module CamaleonCms
  class PostUniqValidator < ActiveModel::Validator
    def validate(record)
      return if record.draft?

      slug_array = record.slug.to_s.translations_array
      ptype = record.post_type
      return unless ptype.present? # only for posts that belongs to a post type model

      posts = ptype.site.posts
                   .where(
                     "(#{slug_array.map { |s| "#{CamaleonCms::Post.table_name}.slug LIKE '%-->#{s}<!--%'" }
                                        .join(' OR ')} ) OR #{CamaleonCms::Post.table_name}.slug = ?", record.slug
                   )
                   .where.not(id: record.id)
                   .where.not(status: %i[draft draft_child trash])
      if posts.size.positive?
        record.errors[:base] << if slug_array.size > 1
                                  "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{posts.pluck(:slug).map do |slug|
                                                                                                             record.slug.to_s.translations.map do |lng, r_slug|
                                                                                                               if slug.translations_array.include?(r_slug)
                                                                                                                 "#{r_slug} (#{lng})"
                                                                                                               end
                                                                                                             end.join(',')
                                                                                                           end.join(',').split(',').uniq.clean_empty.join(', ')} "
                                else
                                  "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{record.slug} "
                                end
      end

      # avoid recursive page parent
      if record.post_parent.present? && ptype.manage_hierarchy? && record.parents.cama_pluck(:id).include?(record.id)
        record.errors[:base] << I18n.t('camaleon_cms.admin.post.message.recursive_hierarchy',
                                       default: 'Parent Post Recursive')
      end
    end
  end
end
