# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'STI discriminator compatibility', type: :model do
  let(:conn) { ActiveRecord::Base.connection }

  def insert_row(table, columns)
    now = conn.quote(Time.current)
    cols = "#{columns.keys.join(', ')}, created_at, updated_at"
    vals = "#{columns.values.map { |v| conn.quote(v) }.join(', ')}, #{now}, #{now}"
    conn.execute("INSERT INTO #{table} (#{cols}) VALUES (#{vals})")
    conn.select_value("SELECT MAX(id) FROM #{table}")
  end

  describe 'term_taxonomy discriminator' do
    let(:table) { CamaleonCms::TermTaxonomy.table_name }

    it 'reads an existing row with a custom taxonomy value as the STI root' do
      id = insert_row(table, taxonomy: 'custom_tax', name: 'Custom Row')

      record = CamaleonCms::TermTaxonomy.find(id)

      expect(record).to be_instance_of(CamaleonCms::TermTaxonomy)
      expect(record.taxonomy).to eq('custom_tax')
    end

    it 'loads relations that include custom-taxonomy rows' do
      insert_row(table, taxonomy: 'custom_tax', name: 'Custom Relation Row')

      expect { CamaleonCms::TermTaxonomy.where(name: 'Custom Relation Row').to_a }.not_to raise_error
    end

    it 'creates and persists a record with a custom taxonomy value' do
      record = CamaleonCms::TermTaxonomy.new(taxonomy: 'custom_tax', name: 'Created Custom')
      record.save!

      expect(record.reload.taxonomy).to eq('custom_tax')
    end

    it 'still resolves built-in values to their subclasses' do
      category = CamaleonCms::Category.first

      expect(CamaleonCms::TermTaxonomy.find(category.id)).to be_instance_of(CamaleonCms::Category)
    end

    it 'treats a value resolving to a non-descendant class as unknown' do
      id = insert_row(table, taxonomy: 'meta', name: 'Impostor Row')

      expect(CamaleonCms::TermTaxonomy.find(id)).to be_instance_of(CamaleonCms::TermTaxonomy)
    end
  end

  describe 'posts discriminator' do
    let(:table) { CamaleonCms::PostDefault.table_name }

    it 'reads a row with an unknown post_class as the STI root' do
      id = insert_row(table, post_class: 'External::Unknown', title: 'Foreign Post', status: 'published')

      record = CamaleonCms::PostDefault.find(id)

      expect(record).to be_instance_of(CamaleonCms::PostDefault)
      expect(record.post_class).to eq('External::Unknown')
    end
  end
end
