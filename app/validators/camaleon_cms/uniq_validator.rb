module CamaleonCms
  class UniqValidator < ActiveModel::Validator
    def validate(record)
      unless record.skip_slug_validation?
        record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}" if CamaleonCms::TermTaxonomy.where(slug: record.slug).where.not(id: record.id).where("#{CamaleonCms::TermTaxonomy.table_name}.taxonomy" => record.taxonomy).where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id" => record.parent_id).size > 0
      end
    end
  end
end
