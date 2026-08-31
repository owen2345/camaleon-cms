# frozen_string_literal: true

namespace :camaleon_cms do
  # Repairs media visibility flags after the get_media_collection routing fix.
  #
  # Rows written before that fix stored `is_public` as the opposite of the file's real
  # visibility. Media rows are a pure cache of storage — every column is derived by the
  # uploaders' browser_files/file_parse — so instead of transforming rows in place (any blind
  # flip corrupts rows that were already correct: rows written after the fix deployed, or by
  # direct association writers, and it is unsafe to repeat), this task purges the cache and
  # lets it rebuild from storage through the corrected routing, which derives each flag from
  # where the file actually lives. Convergent by construction: safe to run any number of
  # times, concurrently, or on an already-correct database — no marker, no run-once guard.
  #
  # Local sites get their public collection rebuilt eagerly here; private collections and
  # cloud-storage (AWS) sites rebuild lazily on their next media browse — the same path the
  # admin clear-cache action relies on. Run this immediately after deploying the routing fix,
  # before further media activity.
  desc 'Repair media is_public flags: purge the media cache and rebuild it from storage ' \
       '(pairs with the get_media_collection routing fix). Convergent: safe to re-run.'
  task repair_media_visibility: :environment do
    report = CamaleonCms::TaskReporter

    # Batched: short transactions instead of one table-length lock. A partial purge is safe —
    # it only leaves fewer stale rows, and a re-run finishes the job.
    purged = CamaleonCms::Media.in_batches.delete_all

    rebuilt_sites = 0
    lazy_sites = 0
    CamaleonCms::Site.find_each do |site_record|
      site = site_record.decorate
      if site.get_option('filesystem_type', 'local').to_s.casecmp?('local')
        CamaleonCmsLocalUploader.new({ current_site: site }, nil).reload
        rebuilt_sites += 1
      else
        lazy_sites += 1
      end
    end

    report.call "camaleon_cms:repair_media_visibility: purged #{purged} cached media row(s); " \
                "rebuilt the public media cache for #{rebuilt_sites} local site(s)."
    report.call "#{lazy_sites} cloud-storage site(s) rebuild on their next media browse." if lazy_sites > 0
    report.call 'Private media caches rebuild on their next private media browse.'
  end
end
