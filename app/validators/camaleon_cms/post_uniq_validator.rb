module CamaleonCms
  class PostUniqValidator < ActiveModel::Validator
    def validate(record)
      return if record.draft?

      slug_array = record.slug.to_s.translations_array
      ptype = record.post_type
      return unless ptype.present?

      post_table = CamaleonCms::Post.table_name

      conditions = []
      params = []

      slug_array.each do |s|
        conditions << "#{post_table}.slug LIKE ?"
        params << "%-->#{s}<!--%"
      end

      conditions << "#{post_table}.slug = ?"
      params << record.slug

      where_clause = "(#{conditions.join(' OR ')})"

      posts = ptype.site.posts
                   .where(where_clause, *params)
                   .where.not(id: record.id)
                   .where.not(status: %i[draft draft_child trash])
      unless posts.empty?
        record.errors[:base] <<
          if slug_array.size > 1
            "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{posts.pluck(:slug).map do |slug|
              record.slug.to_s.translations.map do |lng, r_slug|
                "#{r_slug} (#{lng})" if slug.translations_array.include?(r_slug)
              end.join(',')
            end.join(',').split(',').uniq.clean_empty.join(', ')} "
          else
            "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{record.slug} "
          end
      end

      return unless record.post_parent.present? && ptype.manage_hierarchy? &&
                    record.parents.cama_pluck(:id).include?(record.id)

      record.errors[:base] << I18n.t('camaleon_cms.admin.post.message.recursive_hierarchy',
                                     default: 'Parent Post Recursive')
    end
  end
end
