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

      # Scans every file under `root`, reporting those today's rules would refuse. `label` names the
      # location and `base` anchors the reported path. Closes over the counters so the public and
      # private roots share one pass rather than duplicating the scan logic (and risking drift).
      # FNM_DOTMATCH so dotfiles are scanned: a basename that is entirely an extension (`.svg`, `.js`)
      # is exactly what the scanner fail-closes on. `.`/`..` are directory entries File.file? drops.
      scan_tree = lambda do |root, base, label|
        next unless root.directory?

        Dir.glob(root.join('**', '*'), File::FNM_DOTMATCH).sort.each do |path|
          next unless File.file?(path)

          scanned += 1
          relative = Pathname.new(path).relative_path_from(base)
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
          report.call "✗ #{label} /#{relative}: would be rejected (#{reason})"
        end
      end

      CamaleonCms::Site.unscoped.find_each do |site|
        # Site#upload_directory honours the `media_slug_folder` config, which stores uploads under
        # media/<slug> instead of media/<id>. Hardcoding the id scanned nothing on a slug-configured
        # install and printed a clean "0 would be rejected" -- a false all-clear.
        scan_tree.call(Pathname.new(site.upload_directory), Rails.public_path, "Site #{site.id}")
      end

      # Private media is scanned at upload time exactly like public media, so files stored before
      # these rules apply are equally worth surfacing. It lives outside the public root, under its
      # own directory, so it is scanned separately and reported relative to the app root.
      scan_tree.call(Rails.root.join(CamaleonCmsUploader::PRIVATE_DIRECTORY), Rails.root, 'Private media')

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
