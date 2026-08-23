# frozen_string_literal: true

# Security (audit 2026-08-11, Tier-2 #8): CollectionProxy#sort_by_field interpolated its `order`
# argument straight into the SQL ORDER BY clause (`.reorder("...value #{order}")`). sort_by_field is
# a documented public API themes and plugins call as `collection.sort_by_field(key, params[:order])`,
# so a user-controlled direction reached an ORDER BY injection sink across the trust boundary.
#
# On the supported Rails range (6.1+) ActiveRecord's disallow_raw_sql! guard rejects arbitrary raw
# SQL here, so a stacked/comment payload does not execute -- but it raises UnknownAttributeReference
# (an unhandled 500), and the guard still permits comma-separated ORDER BY continuations, letting an
# attacker append extra `<column> <direction>` terms (a blind ordering oracle). The fix whitelists
# the direction to ASC/DESC and orders by a quoted Arel column, so a hostile direction can neither
# raise nor inject additional ORDER BY terms -- and the method no longer relies on Rails' implicit
# raw-SQL guard.
RSpec.describe 'CollectionProxy custom-field helpers', type: :model do
  init_site

  let(:site) { Cama::Site.first }

  describe 'sort_by_field ORDER BY injection' do
    let(:post_type) { create(:post_type, slug: 'sortable-pt', site: site) }
    let!(:post_a) { create(:post, post_type: post_type, slug: 'sortable-a', site: site) }
    let!(:post_b) { create(:post, post_type: post_type, slug: 'sortable-b', site: site) }
    let(:field) do
      group = post_a.add_custom_field_group(name: 'Sort Group', slug: 'sort-group')
      group.add_manual_field({ name: 'Rank', slug: 'rank' }, { field_key: 'text_box' })
    end
    let(:field_key) { 'rank' }
    let(:cfr_table) { CamaleonCms::CustomFieldsRelationship.table_name }

    # The values are deliberately anti-correlated with creation order (post_a has the higher value
    # despite the lower id), so ordering by any other column -- posts.id, the CFR row id/objectid --
    # fails these examples: they pass only when the sort really reads the custom-field value.
    before do
      post_a.custom_field_values.create!(custom_field_id: field.id, custom_field_slug: field_key, value: 'Banana')
      post_b.custom_field_values.create!(custom_field_id: field.id, custom_field_slug: field_key, value: 'Apple')
    end

    describe 'legitimate directions still sort' do
      it 'orders ascending' do
        expect(post_type.posts.sort_by_field(field_key, 'asc').map(&:id)).to eq([post_b.id, post_a.id])
      end

      it 'orders descending' do
        expect(post_type.posts.sort_by_field(field_key, 'desc').map(&:id)).to eq([post_a.id, post_b.id])
      end

      it 'honors a padded descending direction' do
        expect(post_type.posts.sort_by_field(field_key, ' desc ').map(&:id)).to eq([post_a.id, post_b.id])
      end

      it 'honors the direction token of a modifier-bearing direction' do
        expect(post_type.posts.sort_by_field(field_key, 'DESC NULLS LAST').map(&:id)).to eq([post_a.id, post_b.id])
      end

      it 'defaults to ascending when no direction is given' do
        expect(post_type.posts.sort_by_field(field_key).map(&:id)).to eq([post_b.id, post_a.id])
      end
    end

    describe 'a hostile direction' do
      # A stacked/comment payload: Rails' raw-SQL guard raises on this today (an unhandled 500); it
      # must instead be neutralised to a plain ascending sort.
      let(:stacked_payload) { "ASC; DROP TABLE #{cfr_table}; --" }
      # A comma continuation: this slips past Rails' guard and appends an attacker-chosen ORDER BY term.
      let(:comma_payload) { "ASC, #{cfr_table}.term_order DESC" }

      it 'is neutralised to a plain ascending sort without raising' do
        relation = post_type.posts.sort_by_field(field_key, stacked_payload)

        expect { relation.load }.not_to raise_error
        expect(relation.map(&:id)).to eq([post_b.id, post_a.id])
      end

      it 'orders only by the value column, identically to a plain ascending sort' do
        baseline = post_type.posts.sort_by_field(field_key, 'asc').to_sql
        sql = post_type.posts.sort_by_field(field_key, comma_payload).to_sql

        expect(sql).to eq(baseline)
      end
    end
  end

  # Review follow-up to the fix above: both helpers used CollectionProxy#build for class discovery,
  # and #build also appends the built record to the association's in-memory target -- so every call
  # added two phantom unsaved records to the collection it was called on (visible on later iteration,
  # and failing a later owner save via autosave validation). Class discovery must not mutate the
  # collection.
  describe 'collection integrity' do
    let(:post_type) { create(:post_type, slug: 'integrity-pt', site: site) }

    before { create(:post, post_type: post_type, slug: 'integrity-a', site: site) }

    it 'sort_by_field does not append phantom records to the collection it sorts' do
      collection = post_type.posts

      expect { collection.sort_by_field('rank') }.not_to change(collection, :size)
    end

    it 'filter_by_field does not append phantom records to the collection it filters' do
      collection = post_type.posts

      expect { collection.filter_by_field('rank') }.not_to change(collection, :size)
    end
  end
end
