# frozen_string_literal: true

namespace :camaleon_cms do
  namespace :security do
    # The scan-and-reject gates refuse dangerous content at save time but never rewrite what is
    # already stored (nothing is ever rewritten under this model). This task lists the stored
    # content that would fail today's gates -- post content and summaries, gated custom-field values,
    # post templates, layouts and default views outside the site's theme, options rows that are not
    # JSON objects, and post type decorator class options -- so an operator can review and clean it
    # up by hand. Read-only: it changes nothing.
    desc 'List stored post content and summaries, custom-field values, post templates and layouts, ' \
         'options rows and post type decorator classes that would fail the scan-and-reject gates'
    task scan_content: :environment do
      report = CamaleonCms::TaskReporter
      report.call 'Scanning stored content against the scan-and-reject gates (read-only)...'
      flagged = 0

      content_rejected = lambda do |value|
        CamaleonCms::UnsafeMarkup.unsafe_html?(value, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                                                      attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES)
      end

      # The post save holds a non-admin's template, layout and default views to the lists the editor
      # offers, which need a request (the current theme plus the post_get_list_* hooks). Outside one,
      # a stored value is compared against the site's theme view files, the same globs the listers
      # read; a plugin hook may still offer a value listed here, so each line says so.
      theme_views = Hash.new do |cache, site|
        path = site && PluginRoutes.theme_info(site.get_theme_slug)&.dig('path')
        names = ->(*dir) { Dir[File.join(path, 'views', *dir, '*')].map { |f| File.basename(f).split('.').first } }
        cache[site] = if path
                        { template: names.call.select { |n| n.include?('template_') },
                          layout: names.call('layouts').reject { |n| n.start_with?('_') } }
                      else
                        { template: [], layout: [] }
                      end
      end
      view_lines = lambda do |record, site, views|
        views.filter_map do |field, kind|
          value = record.send(field.start_with?('default_') ? :get_option : :get_meta, field)
          next if value.blank? || !value.is_a?(String) || theme_views[site][kind].include?(value)

          "#{field} '#{value.truncate(80)}' is not a view of the site's theme (a plugin hook may still offer it)"
        end
      end
      # Metas#options reads a row that is not a JSON object as no options, so nothing raises on it
      # any more; the row itself is still wrong and is listed from the raw value.
      options_row_readable = lambda do |record|
        row = record.metas.find { |meta| meta.key == '_default' }
        row.nil? || row.value.blank? || JSON.parse(row.value, allow_duplicate_key: true).is_a?(Hash)
      rescue JSON::ParserError
        false
      end

      CamaleonCms::Post.unscoped.preload(:metas, post_type: :site).find_each do |post|
        site = post.post_type&.site
        lines = []
        lines << 'content would be rejected' if post.content.present? && content_rejected.call(post.content)
        if post.get_meta('summary').present? && content_rejected.call(post.get_meta('summary'))
          lines << 'summary would be rejected'
        end
        lines << 'options could not be read; review its _default meta' unless options_row_readable.call(post)
        lines.concat(view_lines.call(post, site, 'template' => :template, 'layout' => :layout,
                                                 'default_template' => :template, 'default_layout' => :layout))
        lines.each do |line|
          flagged += 1
          report.call "✗ Post id=#{post.id} (#{post.post_class}) '#{post.slug.to_s.truncate(60)}': #{line}"
        end
      rescue StandardError => e
        flagged += 1
        report.call "✗ Post id=#{post.id} (#{post.post_class}): could not be scanned (#{e.class}); review its metas"
      end

      # Reuse the model's own gate dispatch (which covers editor, field_attrs and URI field types),
      # so the scan can never diverge from what the save-time validation would refuse.
      CamaleonCms::CustomFieldsRelationship.unscoped.where.not(value: [nil, ''])
                                           .includes(:custom_field).find_each do |row|
        field_key = row.custom_field&.options&.[](:field_key).to_s
        next unless CamaleonCms::CustomFieldsRelationship.gate_rejection_reason(field_key, row.value)

        flagged += 1
        report.call "✗ Custom-field value id=#{row.id} field='#{row.custom_field_slug}' " \
                    "(#{field_key}) on #{row.object_class} ##{row.objectid}: value would be rejected"
      end

      # A post type's decorator class option is loaded as code and held to CamaleonCms::PostDecorator
      # subclasses at save (PostType#set_meta); a stored value that names no loadable post decorator
      # (written before that check, left by a removed plugin, imported) is ignored at render and listed
      # here, through the same resolver the check uses. A post type whose options cannot be read is
      # listed too, so one bad row does not end the scan.
      option = CamaleonCms::PostType::DECORATOR_CLASS_OPTION
      CamaleonCms::PostType.unscoped.preload(:metas, :site).find_each do |post_type|
        lines = []
        lines << 'options could not be read; review its _default meta' unless options_row_readable.call(post_type)
        value = post_type.get_option(option)
        unless CamaleonCms::PostType.decorator_class_for(value)
          lines << "#{option} '#{value}' is not a loadable CamaleonCms::PostDecorator subclass and is ignored"
        end
        lines.concat(view_lines.call(post_type, post_type.site,
                                     'default_template' => :template, 'default_layout' => :layout))
        lines.each do |line|
          flagged += 1
          report.call "✗ Post type id=#{post_type.id} '#{post_type.slug}': #{line}"
        end
      rescue StandardError => e
        flagged += 1
        report.call "✗ Post type id=#{post_type.id} '#{post_type.slug}': could not be scanned " \
                    "(#{e.class}); review its _default meta"
      end

      report.call "Done. #{flagged} stored item(s) would be rejected by today's gates."
      report.call 'Nothing was modified; review and clean up the listed items by hand.'
    end
  end
end
