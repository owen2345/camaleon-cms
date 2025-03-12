# frozen_string_literal: true

module CamaleonCms
  module NormalizeAttrs
    def normalize_attrs(*args)
      # TODO: Remove the 1st branch when support will be dropped of Rails < 7.1
      if ::Rails::VERSION::STRING < '7.1.0'
        before_validation(on: %i[create update]) do
          args.each do |attr|
            next unless new_record? || attribute_changed?(attr)

            self[attr] = ActionController::Base.helpers.sanitize(
              __send__(attr)&.gsub(CamaleonRecord::TRANSLATION_TAG_HIDE_REGEX, CamaleonRecord::TRANSLATION_TAG_HIDE_MAP)
            )&.gsub(CamaleonRecord::TRANSLATION_TAG_RESTORE_REGEX, CamaleonRecord::TRANSLATION_TAG_RESTORE_MAP)
          end
        end
      else
        normalizes(*args, with: lambda { |field|
          ActionController::Base.helpers.sanitize(
            field.gsub(CamaleonRecord::TRANSLATION_TAG_HIDE_REGEX, CamaleonRecord::TRANSLATION_TAG_HIDE_MAP)
          ).gsub(CamaleonRecord::TRANSLATION_TAG_RESTORE_REGEX, CamaleonRecord::TRANSLATION_TAG_RESTORE_MAP)
        })
      end
    end
  end
end
