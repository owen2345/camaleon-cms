# frozen_string_literal: true

namespace :camaleon_cms do
  desc 'Re-apply the owner-only ACL to S3 objects under each AWS site\'s private upload prefix ' \
       '(uploads stored before the private-ACL fix were world-readable). ' \
       'Set CAMA_S3_INNER_FOLDER for setups whose uploader hook configures an inner_folder.'
  task repair_private_upload_acls: :environment do
    inner_folder = ENV['CAMA_S3_INNER_FOLDER'].to_s
    repaired_total = 0
    swept_sites = 0

    CamaleonCms::Site.find_each do |site_record|
      site = site_record.decorate
      next unless %w[aws s3].include?(site.get_option('filesystem_type', 'local').to_s.downcase)

      uploader = CamaleonCmsAwsUploader.new({ current_site: site,
                                              aws_settings: { 'inner_folder' => inner_folder } }, nil)
      repaired = uploader.repair_private_acls!
      swept_sites += 1
      repaired_total += repaired
      puts "  #{site.the_slug}: #{repaired} object(s) re-ACLed"
    end

    summary = "camaleon_cms:repair_private_upload_acls re-ACLed #{repaired_total} object(s) " \
              "across #{swept_sites} AWS site(s)"
    Rails.logger.info(summary)
    # An operator runs this from a terminal, where Rails.logger writes to a file they are not
    # watching. Without this the task looks like it did nothing.
    puts summary
  end
end
