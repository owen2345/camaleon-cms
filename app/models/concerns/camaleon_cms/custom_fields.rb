# frozen_string_literal: true

module CamaleonCms
  module CustomFields
    extend ActiveSupport::Concern
    included do
      has_many :field_groups, as: :record, dependent: :destroy, inverse_of: :record
      has_many :fields, through: :field_groups, as: :record
      has_many :field_values, as: :record, dependent: :destroy, inverse_of: :record
    end
  end
end
