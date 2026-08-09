namespace :camaleon_cms do
  desc 'Backfill user roles to include custom_fields manager permission'
  task backfill_custom_fields_permission: :environment do
    # Log for the record AND print to stdout: an operator runs this from a terminal, where
    # Rails.logger writes to a file they are not watching, so a logger-only task looks like a no-op.
    report = lambda do |msg|
      Rails.logger.info(msg)
      puts msg
    end
    report.call 'Backfilling custom_fields manager permission for existing user roles...'
    CamaleonCms::UserRole.find_each do |role|
      key = "_manager_#{role.parent_id}"
      begin
        current_role = role.get_meta(key)
        # if the role already has settings/managers, skip; otherwise add custom_fields => 1
        if current_role.blank? || (!current_role.is_a?(Hash) || current_role['custom_fields'].blank?)
          current_role = (current_role.is_a?(Hash) ? current_role : {}).merge!('custom_fields' => 1)
          role.set_meta(key, current_role)
          report.call "Updated role=#{role.slug} site_id=#{role.parent_id}"
        else
          report.call "Skipped role=#{role.slug} site_id=#{role.parent_id} (already has custom_fields)"
        end
      rescue StandardError => e
        report.call "Failed to update role=#{role.slug}: #{e.message}"
      end
    end
    report.call 'Done.'
  end

  desc 'Backfill admin user roles to include select_eval permission'
  task backfill_select_eval_permission: :environment do
    report = lambda do |msg|
      Rails.logger.info(msg)
      puts msg
    end
    report.call 'Backfilling select_eval permission for admin roles...'
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
          report.call "✓ Updated admin role site_id=#{site_id}"
          updated_count += 1
        else
          report.call "  Skipped admin role site_id=#{site_id} (already has select_eval)"
          skipped_count += 1
        end
      rescue StandardError => e
        report.call "✗ Failed to update admin role site_id=#{site_id}: #{e.message}"
      end
    end

    report.call "\nSummary:"
    report.call "  Updated: #{updated_count} admin roles"
    report.call "  Skipped: #{skipped_count} admin roles"
    report.call "\nDone! All admin roles now have select_eval permission."
  end
end
