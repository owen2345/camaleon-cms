# frozen_string_literal: true

namespace :camaleon_cms do
  # One-time data correction paired with the get_media_collection routing fix.
  #
  # Media rows written before that fix stored `is_public` as the OPPOSITE of the file's real
  # visibility (private files as `is_public: true` and vice versa). The code now writes the flag
  # correctly; this task realigns the rows already in the table by inverting `is_public` once.
  #
  # `is_public = NOT is_public` is its own inverse, so running it twice would re-break the data.
  # It therefore records a marker on the first site and skips when that marker is present; the flip
  # and the marker share one transaction, so an interrupted run leaves no marker and re-runs safely.
  # Run it immediately after deploying the routing fix on an existing install.
  desc 'One-time: invert media.is_public so the stored flag matches each file\'s real visibility ' \
       '(pairs with the get_media_collection routing fix). Idempotent: a second run is a no-op.'
  task backfill_media_is_public: :environment do
    report = CamaleonCms::TaskReporter
    marker_key = 'media_is_public_backfill_v1'

    # Camaleon's conventional global-settings holder. Resolved freshly (not via the memoized
    # Site.main_site) so the marker always reads/writes against the real first row.
    site = CamaleonCms::Site.reorder(id: :asc).first
    if site.nil?
      report.call 'camaleon_cms:backfill_media_is_public: no site found; nothing to back-fill.'
      next
    end

    # Read the marker straight off the metas relation (not get_meta, whose value cache a rolled-back
    # run in a shared store could otherwise poison).
    if site.metas.where(key: marker_key).exists?
      report.call 'camaleon_cms:backfill_media_is_public: already completed on this database; ' \
                  'nothing to do.'
      next
    end

    flipped = 0
    ActiveRecord::Base.transaction do
      # NULL is_public (only reachable for pre-validation rows) is left untouched: it is a separate
      # orphaning concern, not part of the inversion.
      rows = CamaleonCms::Media.where.not(is_public: nil)
      # One bulk SQL flip: validations/callbacks are irrelevant to an in-place boolean inversion,
      # and per-row saves would be needless work.
      flipped = rows.update_all('is_public = NOT is_public') # rubocop:disable Rails/SkipsModelValidations
      site.metas.create!(key: marker_key,
                         value: "backfilled #{flipped} row(s) at #{Time.now.utc.iso8601}")
    end

    report.call "camaleon_cms:backfill_media_is_public: inverted is_public on #{flipped} media " \
                'row(s). The stored flag now matches real visibility.'
  end
end
