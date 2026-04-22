namespace :camaleon_cms do
  desc 'Backfill user roles to include custom_fields manager permission'
  task backfill_custom_fields_permission: :environment do
    Rails.logger.info 'Backfilling custom_fields manager permission for existing user roles...'
    CamaleonCms::UserRole.find_each do |role|
      key = "_manager_#{role.parent_id}"
      begin
        current_role = role.get_meta(key)
        # if the role already has settings/managers, skip; otherwise add custom_fields => 1
        if current_role.blank? || (!current_role.is_a?(Hash) || current_role['custom_fields'].blank?)
          current_role = (current_role.is_a?(Hash) ? current_role : {}).merge!('custom_fields' => 1)
          role.set_meta(key, current_role)
          Rails.logger.info "Updated role=#{role.slug} site_id=#{role.parent_id}"
        else
          Rails.logger.info "Skipped role=#{role.slug} site_id=#{role.parent_id} (already has custom_fields)"
        end
      rescue StandardError => e
        Rails.logger.info "Failed to update role=#{role.slug}: #{e.message}"
      end
    end
    Rails.logger.info 'Done.'
  end

  desc 'Backfill admin user roles to include select_eval permission'
  task backfill_select_eval_permission: :environment do
    Rails.logger.info 'Backfilling select_eval permission for admin roles...'
    updated_count = 0
    skipped_count = 0

    CamaleonCms::UserRole.where(slug: 'admin', term_group: -1).find_each do |role|
      site_id = role.parent_id
      key = "_manager_#{site_id}"
      begin
        current_meta = role.get_meta(key, {})

        # Only update if role doesn't already have select_eval
        if !current_meta[:select_eval]
          updated_meta = current_meta.merge(select_eval: 1)
          role.set_meta(key, updated_meta)
          Rails.logger.info "✓ Updated admin role site_id=#{site_id}"
          updated_count += 1
        else
          Rails.logger.info "  Skipped admin role site_id=#{site_id} (already has select_eval)"
          skipped_count += 1
        end
      rescue StandardError => e
        Rails.logger.info "✗ Failed to update admin role site_id=#{site_id}: #{e.message}"
      end
    end

    Rails.logger.info "\nSummary:"
    Rails.logger.info "  Updated: #{updated_count} admin roles"
    Rails.logger.info "  Skipped: #{skipped_count} admin roles"
    Rails.logger.info "\nDone! All admin roles now have select_eval permission."
  end
end
