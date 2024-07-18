module CamaleonCms
  class UniqValidator < ActiveModel::Validator
    def validate(record)
      return if record.skip_slug_validation?

      taxonomy_table = CamaleonCms::TermTaxonomy.table_name
      slug_exists = CamaleonCms::TermTaxonomy.where(slug: record.slug)
                                             .where.not(id: record.id)
                                             .where("#{taxonomy_table}.taxonomy" => record.taxonomy)
                                             .where("#{taxonomy_table}.parent_id" => record.parent_id).exists?

      return unless slug_exists

      record.errors[:base] << I18n.t('camaleon_cms.admin.post.message.requires_different_slug').to_s
    end
  end
end
