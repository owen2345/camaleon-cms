namespace :camaleon_cms do
  desc 'Backfill user roles to include custom_fields manager permission'
  task backfill_custom_fields_permission: :environment do
    puts 'Backfilling custom_fields manager permission for existing user roles...'
    CamaleonCms::UserRole.find_each do |role|
      key = "_manager_#{role.parent_id}"
      begin
        current_role = role.get_meta(key)
        # if the role already has settings/managers, skip; otherwise add custom_fields => 1
        if current_role.blank? || (!current_role.is_a?(Hash) || current_role['custom_fields'].blank?)
          current_role = (current_role.is_a?(Hash) ? current_role : {}).merge!('custom_fields' => 1)
          role.set_meta(key, current_role)
          puts "Updated role=#{role.slug} site_id=#{role.parent_id}"
        else
          puts "Skipped role=#{role.slug} site_id=#{role.parent_id} (already has custom_fields)"
        end
      rescue StandardError => e
        puts "Failed to update role=#{role.slug}: #{e.message}"
      end
    end
    puts 'Done.'
  end
end
