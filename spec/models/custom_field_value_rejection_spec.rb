# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M17, scan-and-reject policy): the frontend renders an `editor`
# custom-field value verbatim and URI-type values into href/src, so a value an untrusted author may
# not write is refused on save -- never rewritten. Trusted authors (admins, or a role holding
# post_content_unfiltered_html for the post type) store exactly what they wrote. Field types that
# render through escaping ERB as element content carry no gate.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:site) { create(:site) }
  let(:post_type) { create(:post_type, site: site) }
  let(:admin) { create(:user, role: 'admin', site: site) }
  let(:contributor) { create(:user, role: 'contributor', site: site) }
  let(:post) { create(:post, post_type: post_type, owner: contributor) }
  let(:script) { '<p>keep</p><script>alert(1)</script>' }

  before do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: site)
    group.add_manual_field({ name: 'Body', slug: 'body' }, { field_key: 'editor' })
    group.add_manual_field({ name: 'Link', slug: 'link' }, { field_key: 'url' })
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
    group.add_manual_field({ name: 'Specs', slug: 'specs' }, { field_key: 'field_attrs' })
  end

  def as_user(user)
    CurrentRequest.user = user
    CurrentRequest.site = site
  end

  after do
    CurrentRequest.user = nil
    CurrentRequest.site = nil
  end

  describe 'editor values (markup position)' do
    it 'refuses a script value from an untrusted author and stores nothing' do
      as_user(contributor)

      expect { post.set_field_value('body', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(post.get_field_value('body')).to be_blank
    end

    it 'stores legitimate rich text from an untrusted author unchanged' do
      as_user(contributor)
      table = '<table><tbody><tr><td colspan="2">cell</td></tr></tbody></table>'

      post.set_field_value('body', table)

      expect(post.get_field_value('body')).to eq(table)
    end

    it 'stores an admin author value verbatim, script included' do
      as_user(admin)

      post.set_field_value('body', script)

      expect(post.get_field_value('body')).to eq(script)
    end

    it 'trusts a non-admin role granted post_content_unfiltered_html for the post type' do
      editor = create(:user, role: 'editor', site: site)
      site.user_roles.find_by(slug: 'editor')
          .set_meta("_post_type_#{site.id}", edit: [post_type.id], post_content_unfiltered_html: [post_type.id])
      as_user(editor)

      post.set_field_value('body', script)

      expect(post.get_field_value('body')).to eq(script)
    end

    it 'fails closed without a request context' do
      expect { post.set_field_value('body', script) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'still saves benign values without a request context' do
      post.set_field_value('body', '<p>seeded</p>')

      expect(post.get_field_value('body')).to eq('<p>seeded</p>')
    end

    it 'lets an explicit server-side opt-out store a value unchanged' do
      field_id = post.get_field_object('body').id
      row = post.custom_field_values.new(custom_field_id: field_id, custom_field_slug: 'body', value: script)

      row.unfiltered_value!.save!

      expect(post.get_field_value('body')).to eq(script)
    end
  end

  describe 'URI values (href/src position)' do
    it 'refuses a script-scheme URL from an untrusted author' do
      as_user(contributor)

      expect { post.set_field_value('link', 'javascript:alert(1)') }
        .to raise_error(ActiveRecord::RecordInvalid, /script-capable URL/)
    end

    it 'stores an ordinary URL' do
      as_user(contributor)

      post.set_field_value('link', 'https://example.com/page')

      expect(post.get_field_value('link')).to eq('https://example.com/page')
    end
  end

  describe 'escaped element-content positions' do
    it 'carries no gate for values the renderer escapes' do
      as_user(contributor)

      post.set_field_value('note', script)

      expect(post.get_field_value('note')).to eq(script)
    end
  end

  describe 'field_attrs values (verbatim JSON markup position)' do
    it 'refuses a script hidden in the pair for an untrusted author' do
      as_user(contributor)
      literal = JSON.generate(attr: 'Color', value: script) # stdlib generate: literal markup bytes

      expect { post.set_field_value('specs', literal) }
        .to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
    end

    it 'refuses markup the JSON encoder unicode-escaped (no literal angle bracket in the bytes)' do
      as_user(contributor)
      # What the admin form stores: the ActiveSupport encoder escapes markup
      # (escape_html_entities_in_json), so the stored bytes carry no "<" -- but JSON.parse
      # restores it and the renderer emits it verbatim.
      escaped = { attr: 'Color', value: script }.to_json
      expect(escaped).not_to include('<script')

      expect { post.set_field_value('specs', escaped) }
        .to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
    end

    it 'stores a benign pair unchanged' do
      as_user(contributor)
      pair = { attr: 'Color', value: 'Deep <em>red</em>' }.to_json

      post.set_field_value('specs', pair)

      expect(post.get_field_value('specs')).to eq(pair)
    end

    it 'stores an admin author pair verbatim, script included' do
      as_user(admin)
      pair = { attr: 'Widget', value: script }.to_json

      post.set_field_value('specs', pair)

      expect(post.get_field_value('specs')).to eq(pair)
    end
  end
end
