# frozen_string_literal: true

namespace :camaleon_cms do
  # Through 2.9.2 the custom-fields settings form emitted the raw `user_model` config string as
  # the users placement option, so a namespaced host user model (e.g. 'Admin::User') stored its
  # user field groups under the qualified name — which the demodulized association scope and the
  # 2.9.2 allowed-slugs save filter cannot see. Re-key those group placements to the demodulized
  # contract. Only the group rows move: their fields hang off parent_id under '_fields', group
  # metas key off 'CustomFieldGroup', and value rows were always written under the demodulized
  # name. Keyed to the current config: a host that renamed its user model after writing groups
  # should temporarily restore the historical value while running the task.
  desc 'Re-key user custom field groups stored under a namespaced user_model name'
  task demodulize_user_field_groups: :environment do
    configured = PluginRoutes.static_system_info['user_model'].presence.to_s
    demodulized = configured.demodulize

    if configured.blank? || configured == demodulized
      Rails.logger.info 'Nothing to re-key: the configured user model is not namespaced.'
      next
    end

    count = CamaleonCms::CustomField.unscoped
                                    .where(object_class: configured)
                                    .update_all(object_class: demodulized) # rubocop:disable Rails/SkipsModelValidations
    Rails.logger.info "Re-keyed #{count} user field group(s) from '#{configured}' to '#{demodulized}'."
  end
end
