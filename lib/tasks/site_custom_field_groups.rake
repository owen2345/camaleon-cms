namespace :camaleon_cms do
  # Site#get_field_groups matches a group's placement (object_class + objectid) instead of its
  # tenancy (parent_id). `objectid` has no presence validation, so a group could be persisted with
  # object_class 'Site' and a NULL objectid by bypassing add_custom_field_group. Those rows are
  # invisible on the site settings page under the placement-scoped read, so give them the objectid
  # they should always have had: the site that owns them.
  desc 'Backfill objectid for site custom field groups that were saved without one'
  task backfill_site_field_group_objectid: :environment do
    Rails.logger.info 'Backfilling objectid for site custom field groups...'
    updated_count = 0
    skipped_count = 0

    CamaleonCms::CustomField.unscoped.where(object_class: 'Site', objectid: nil).find_each do |group|
      if group.parent_id.blank?
        Rails.logger.info "  Skipped group id=#{group.id} slug=#{group.slug} (no owning site)"
        skipped_count += 1
        next
      end

      begin
        group.update_column(:objectid, group.parent_id) # rubocop:disable Rails/SkipsModelValidations
        Rails.logger.info "✓ Updated group id=#{group.id} slug=#{group.slug} site_id=#{group.parent_id}"
        updated_count += 1
      rescue StandardError => e
        Rails.logger.info "✗ Failed to update group id=#{group.id}: #{e.message}"
        skipped_count += 1
      end
    end

    Rails.logger.info "\nSummary:"
    Rails.logger.info "  Updated: #{updated_count} field groups"
    Rails.logger.info "  Skipped: #{skipped_count} field groups"
    Rails.logger.info "\nDone."
  end
end
