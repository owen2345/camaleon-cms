# frozen_string_literal: true

module CamaleonCms
  module NormalizeAttrs
    def normalize_attrs(*args)
      # TODO: Remove the 1st branch when support will be dropped of Rails < 7.1
      if ::Rails::VERSION::STRING < '7.1.0'
        before_validation(on: %i[create update]) do
          args.each do |attr|
            next unless new_record? || attribute_changed?(attr)

            self[attr] = CamaleonRecord.cama_sanitize_translatable(__send__(attr))
          end
        end
      else
        normalizes(*args, with: ->(field) { CamaleonRecord.cama_sanitize_translatable(field) })
      end
    end
  end
end
