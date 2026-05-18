# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonRecord, type: :model do
  describe '.polymorphic_class_for' do
    it 'resolves legacy user polymorphic names' do
      expected = CamaManager.get_user_class_name.to_s.constantize

      expect(described_class.polymorphic_class_for('User')).to eq(expected)
    end

    it 'resolves legacy custom field owner types for post type variants' do
      expect(described_class.polymorphic_class_for('PostType_Post')).to eq(CamaleonCms::PostType)
    end

    it 'ignores internal marker polymorphic names' do
      expect(described_class.polymorphic_class_for('_fields')).to be_nil
    end
  end
end
