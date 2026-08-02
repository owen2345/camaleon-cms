namespace :camaleon_cms do
  # A custom field group carries tenancy in `parent_id` (which site owns and administers it) and
  # placement in `object_class` + `objectid` (which record's admin page displays it). Placement reads
  # are not scoped by site, so a group whose two disagree renders on the site owning the placement
  # target while staying invisible in that site's own field group list, which is tenancy-scoped.
  #
  # Re-home rather than delete: a mismatch is not proof of an injection -- a plugin stamping
  # parent_id from the wrong site produces the same shape -- and deleting would take the group's
  # field definitions and their values with it. Setting parent_id to the site that already renders
  # the group restores the invariant and surfaces it where an administrator can judge and remove it.
  desc 'Re-home custom field groups whose owning site differs from the site owning their placement'
  task rehome_cross_site_field_groups: :environment do
    Rails.logger.info 'Re-homing cross-site custom field groups...'
    rehomed_count = 0
    skipped_count = 0

    CamaleonCms::CustomFieldGroup.unscoped.where.not(object_class: '_fields').find_each do |group|
      site_id = cama_placement_site_id(group)

      if site_id.blank?
        Rails.logger.info "  Skipped group id=#{group.id} slug=#{group.slug} " \
                          "(#{group.object_class}/#{group.objectid} does not resolve to a site)"
        skipped_count += 1
        next
      end

      next if site_id == group.parent_id

      begin
        Rails.logger.info "✓ Re-homed group id=#{group.id} slug=#{group.slug} " \
                          "from site_id=#{group.parent_id} to site_id=#{site_id} " \
                          "(placement #{group.object_class}/#{group.objectid})"
        group.update_column(:parent_id, site_id) # rubocop:disable Rails/SkipsModelValidations
        rehomed_count += 1
      rescue StandardError => e
        Rails.logger.info "✗ Failed to re-home group id=#{group.id}: #{e.message}"
        skipped_count += 1
      end
    end

    Rails.logger.info "\nSummary:"
    Rails.logger.info "  Re-homed: #{rehomed_count} field groups"
    Rails.logger.info "  Skipped:  #{skipped_count} field groups"
    Rails.logger.info "\nDone. Review the field group list of any site that gained a group."
  end
end

# Resolve the site owning a group's placement target, or nil when it cannot be determined.
# Best-effort by design: a placement naming a record that no longer exists is left alone rather
# than guessed at or deleted.
def cama_placement_site_id(group)
  objectid = group.objectid
  return nil if objectid.blank?

  case group.object_class
  when 'PostType', 'PostType_Post', 'PostType_Category', 'PostType_PostTag'
    CamaleonCms::PostType.find_by(id: objectid)&.parent_id
  when 'Theme' then CamaleonCms::Theme.find_by(id: objectid)&.parent_id
  when 'Plugin' then CamaleonCms::Plugin.find_by(id: objectid)&.parent_id
  when 'NavMenu' then CamaleonCms::NavMenu.find_by(id: objectid)&.parent_id
  when 'Widget::Main' then CamaleonCms::Widget::Main.find_by(id: objectid)&.parent_id
  when 'Post' then CamaleonCms::Post.find_by(id: objectid)&.post_type&.parent_id
  when 'Category', 'Category_Post' then CamaleonCms::Category.find_by(id: objectid)&.post_type_parent&.parent_id
  when 'PostTag' then CamaleonCms::PostTag.find_by(id: objectid)&.post_type&.parent_id
  else
    # Site, the configured user model, and models registered through the custom_field_custom_models
    # hook are all placed with the site's own id, so the placement target is the site itself.
    CamaleonCms::Site.find_by(id: objectid)&.id
  end
rescue StandardError => e
  Rails.logger.info "  Could not resolve placement for group id=#{group.id}: #{e.message}"
  nil
end
