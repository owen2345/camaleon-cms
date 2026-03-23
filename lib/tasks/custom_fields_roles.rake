namespace :camaleon_cms do
  desc 'Backfill user roles to include custom_fields manager permission'
  task backfill_custom_fields_permission: :environment do
    puts 'Backfilling custom_fields manager permission for existing user roles...'
    CamaleonCms::UserRole.find_each do |role|
      key = "_manager_#{role.site_id}"
      begin
        current = role.get_meta(key) rescue {}
        # if the role already has settings/managers, skip; otherwise add custom_fields => 1
        if current.blank? || (!current.is_a?(Hash) || current['custom_fields'].blank?)
          current = (current.is_a?(Hash) ? current : {}).merge('custom_fields' => 1)
          role.set_meta(key, current)
          puts "Updated role=#{role.slug} site_id=#{role.site_id}"
        else
          puts "Skipped role=#{role.slug} site_id=#{role.site_id} (already has custom_fields)"
        end
      rescue StandardError => e
        puts "Failed to update role=#{role.slug}: #{e.message}"
      end
    end
    puts 'Done.'
  end
end
