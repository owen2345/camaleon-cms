# frozen_string_literal: true

namespace :camaleon_cms do
  namespace :security do
    # The upload rules refuse dangerous content at upload time but never re-examine what is already
    # stored (nothing is ever rewritten under this model). This task lists the stored files today's
    # rules would refuse, so an operator can review them by hand. Read-only: it changes nothing.
    #
    # The companion for authored content is camaleon_cms:security:scan_content.
    desc 'List stored media files that would fail the upload scan rules'
    task scan_uploads: :environment do
      report = CamaleonCms::TaskReporter
      # Reuse the real scanner rather than reimplementing its rules, so the report can never
      # disagree with what an upload of the same bytes would be told today.
      scanner = Class.new { include CamaleonCms::UploaderContentSecurity }.new
      flagged = 0
      scanned = 0

      report.call 'Scanning stored media against the upload scan rules (read-only)...'

      CamaleonCms::Site.unscoped.find_each do |site|
        # Site#upload_directory honours the `media_slug_folder` config, which stores uploads under
        # media/<slug> instead of media/<id>. Hardcoding the id scanned nothing on a slug-configured
        # install and printed a clean "0 would be rejected" -- a false all-clear.
        root = Pathname.new(site.upload_directory)
        next unless root.directory?

        Dir.glob(root.join('**', '*')).sort.each do |path|
          next unless File.file?(path)

          scanned += 1
          relative = Pathname.new(path).relative_path_from(Rails.public_path)
          reason = begin
            scanner.content_unsafe?(File.binread(path), filename: File.basename(path))
          rescue StandardError => e
            # A file the scan cannot read at all is reported rather than skipped: an unreadable
            # entry is exactly what an operator wants to know about, and swallowing it would hand
            # them a false all-clear.
            "unreadable (#{e.class})"
          end
          next unless reason

          flagged += 1
          report.call "✗ Site #{site.id} /#{relative}: would be rejected (#{reason})"
        end
      end

      report.call "Done. #{scanned} stored file(s) scanned, #{flagged} would be rejected by today's rules."
      report.call 'Nothing was modified.'
      if flagged > 0
        report.call 'A finding is not by itself evidence of compromise: these rules are newer than ' \
                    'the files, so content uploaded legitimately under the previous rules is ' \
                    'listed too. Review each one before acting.'
      end
    end
  end
end
