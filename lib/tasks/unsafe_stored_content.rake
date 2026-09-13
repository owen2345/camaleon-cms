# frozen_string_literal: true

namespace :camaleon_cms do
  namespace :security do
    # The scan-and-reject gates refuse dangerous content at save time but never rewrite what is
    # already stored (nothing is ever rewritten under this model). This task lists the stored
    # content that would fail today's gates -- post content, gated custom-field values and post type
    # decorator class options -- so an operator can review and clean it up by hand. Read-only: it
    # changes nothing.
    desc 'List stored post content, custom-field values and post type decorator classes that would fail ' \
         'the scan-and-reject gates'
    task scan_content: :environment do
      report = CamaleonCms::TaskReporter
      report.call 'Scanning stored content against the scan-and-reject gates (read-only)...'
      flagged = 0

      CamaleonCms::Post.unscoped.where.not(content: [nil, '']).find_each do |post|
        next unless CamaleonCms::UnsafeMarkup.unsafe_html?(
          post.content, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                        attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES
        )

        flagged += 1
        report.call "✗ Post id=#{post.id} (#{post.post_class}) '#{post.slug.to_s.truncate(60)}': " \
                    'content would be rejected'
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
      # subclasses at save (PostType#set_meta); a value stored before that check is ignored at render
      # and listed here, through the same resolver the check uses.
      option = CamaleonCms::PostType::DECORATOR_CLASS_OPTION
      CamaleonCms::PostType.unscoped.find_each do |post_type|
        value = post_type.get_option(option)
        next if value.blank? || CamaleonCms::PostType.decorator_class_for(value)

        flagged += 1
        report.call "✗ Post type id=#{post_type.id} '#{post_type.slug}': #{option} '#{value}' names no " \
                    'CamaleonCms::PostDecorator subclass and is ignored'
      end

      report.call "Done. #{flagged} stored item(s) would be rejected by today's gates."
      report.call 'Nothing was modified; review and clean up the listed items by hand.'
    end
  end
end
