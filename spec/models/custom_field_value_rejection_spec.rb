# frozen_string_literal: true

# The frontend renders an `editor` custom-field value verbatim, and URI-type values into href and
# src. The data shortcode puts a value of any kind into the page as markup. So the save refuses a
# value that an untrusted author may not write, for every kind, and never rewrites it. Trusted
# authors store exactly what they wrote: admins, a role holding post_content_unfiltered_html for the
# fields of a post of the post type, a role holding settings or custom_fields for the fields of an
# owner that is not a post, and a role holding theme_settings for the fields of a theme.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:post_type) { installed_post_type }
  let(:site) { post_type.site }
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

    it 'refuses markup in a URL from an untrusted author' do
      as_user(contributor)

      expect { post.set_field_value('link', 'https://example.com/"><script>alert(1)</script>') }
        .to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(post.get_field_value('link')).to be_blank
    end

    it 'stores an ordinary URL' do
      as_user(contributor)

      post.set_field_value('link', 'https://example.com/page')

      expect(post.get_field_value('link')).to eq('https://example.com/page')
    end

    # A url field can be translated. The admin form then stores the translations in markers, and the
    # data shortcode shows one translation, with no marker.
    it 'stores a translated URL unchanged' do
      as_user(contributor)
      translated = { en: 'https://example.com/en', es: 'https://example.com/es' }.to_translate

      post.set_field_value('link', translated)

      expect(post.get_field_value('link')).to eq(translated)
    end

    # String#translate removes the first marker of the locale on each line, so a translation can join
    # a script URL that a marker splits in the stored text.
    it 'refuses a script URL that a translation joins, in each URL kind' do
      value = "<!--:-->java<!--:en-->script:alert(1)\n<!--:en-->"

      %w[url image audio video file].each do |kind|
        expect(described_class.gate_rejection_reason(kind, value)).to eq(:uri), kind
      end
    end

    # A data shortcode inside a tag puts the value into an attribute, as in
    # <img src="[data field='photo']">. A quote, a space or a backtick ends that attribute. Without
    # quotes, a leading space ends the text before the shortcode, as in
    # <img src=https://cdn.test/[data field='photo']>.
    it 'refuses a URL with a character that ends an attribute from an untrusted author' do
      as_user(contributor)

      ['x" onerror="alert(1)', "x' onerror='alert(1)", 'x onerror=alert(1)', "x\tonerror=alert(1)",
       'x`y', ' onerror=alert(1)', "\nhttps://example.com/page"].each do |value|
        expect { post.set_field_value('link', value) }.to raise_error(ActiveRecord::RecordInvalid, /must encode/)
        expect(post.get_field_value('link')).to be_blank
      end
    end

    it 'stores an encoded URL and a URL with whitespace only at its end' do
      as_user(contributor)

      ['https://example.com/a%20b?q=%22x%22', "https://example.com/page \n"].each do |value|
        post.set_field_value('link', value)

        expect(post.get_field_value('link')).to eq(value)
      end
    end

    it 'stores a quote in a text_box value, which the URL rule does not read' do
      as_user(contributor)

      post.set_field_value('note', %(She said "don't" twice))

      expect(post.get_field_value('note')).to eq(%(She said "don't" twice))
    end
  end

  describe 'text_box values (shown as markup by the data shortcode)' do
    it 'refuses a script value from an untrusted author and stores nothing' do
      as_user(contributor)

      expect { post.set_field_value('note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(post.get_field_value('note')).to be_blank
    end

    # The trust check loads the role and its metas. A value that passes the scan does not need it.
    it 'checks no permission of a non-admin for a value that passes the scan' do
      as_user(contributor)
      post # The save of the post checks its own permission.
      expect(CamaleonCms::Ability).not_to receive(:new)

      post.set_field_value('note', 'plain')

      expect(post.get_field_value('note')).to eq('plain')
    end

    it 'stores plain text and allowed markup from an untrusted author unchanged' do
      as_user(contributor)

      ['a < b & c', '<b>bold</b>'].each do |value|
        post.set_field_value('note', value)

        expect(post.get_field_value('note')).to eq(value)
      end
    end
  end

  # The scan refuses a value of any kind that is larger than the parse limit, not only an editor value.
  describe 'the size limit of the scan' do
    it 'refuses a text_box or url value over the limit from an untrusted author' do
      as_user(contributor)
      value = 'a' * (CamaleonCms::UnsafeMarkup::MAX_GATED_VALUE_BYTES + 1)

      %w[note link].each do |slug|
        expect { post.set_field_value(slug, value) }.to raise_error(ActiveRecord::RecordInvalid, /too large/)
        expect(post.get_field_value(slug)).to be_blank
      end
    end
  end

  # SQLite and PostgreSQL store a String in UTF-16 as UTF-8 text, so the scan reads it as UTF-8. A
  # save of such a value raises an encoding error in the model code before the scan (intended), so
  # the example calls the scan itself.
  describe 'a value in UTF-16' do
    it 'is scanned as UTF-8, also by the decoded members of a field_attrs value' do
      tag = '<script>alert(1)</script>'
      escaped = { attr: 'Color', value: tag }.to_json.encode('UTF-16LE')

      expect(described_class.gate_rejection_reason('text_box', tag.encode('UTF-16LE'))).to eq(:html)
      expect(described_class.gate_rejection_reason('field_attrs', escaped)).to eq(:html)
    end
  end

  # String#translations keeps its result on the String, and dup copies that result. So a value that
  # changes in place after a call of translate keeps the translations of its earlier text.
  describe 'a value that changes in place after a call of translate' do
    def changed_in_place(before, after)
      String.new(before).tap(&:translations).replace(after)
    end

    it 'is scanned by the translations of its current text' do
      url = { en: 'https://example.com/' }.to_translate
      pair = { en: { attr: 'Color' }.to_json }.to_translate
      script = { en: { attr: 'Color', value: '<script>alert(1)</script>' }.to_json }.to_translate
      joined = changed_in_place(url, "<!--:-->java<!--:en-->script:x\n<!--:en-->")
      spaced = changed_in_place(url, '<!--:en--> onerror=alert(1)<!--:-->')

      expect(described_class.gate_rejection_reason('url', joined)).to eq(:uri)
      expect(described_class.gate_rejection_reason('url', spaced)).to eq(:url_characters)
      expect(described_class.gate_rejection_reason('field_attrs', changed_in_place(pair, script))).to eq(:html)
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

    # Audit M3: a field_attrs value need not be a top-level object -- a JSON array (or nested)
    # smuggling unicode-escaped script must be scanned member-by-member, not by raw bytes.
    it 'refuses a JSON-array value hiding unicode-escaped script' do
      as_user(contributor)
      arr = [{ attr: 'a', value: script }].to_json
      expect(arr).not_to include('<script')

      expect { post.set_field_value('specs', arr) }
        .to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
    end

    # The data shortcode puts the stored JSON into the page as markup, so the keys of an object are
    # scanned as the members are.
    it 'refuses a script in a key of the JSON object' do
      as_user(contributor)
      keyed = JSON.generate(script => 'x')

      expect { post.set_field_value('specs', keyed) }
        .to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
    end

    # JSON.parse keeps only the last member of a duplicate key, but the stored JSON keeps each member.
    it 'refuses a script in a member that a duplicate key hides, also in a nested object' do
      as_user(contributor)

      [%({"value":"#{script}","value":"x"}), %([{"a":{"b":"#{script}","b":1}}])].each do |hidden|
        expect { post.set_field_value('specs', hidden) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('specs')).to be_blank
      end
    end

    # JSON.parse accepts a comment, and the stored JSON keeps it. A quote in a comment must not hide
    # a member from the scan either.
    it 'refuses a script in a JSON comment, and a script member after a quote in a comment' do
      as_user(contributor)

      [%({"a":1 /* #{script} */}), %({"a":1} // #{script}), %({/* " */"a":"#{script}"}),
       %({"a":1 /* <a href="javascript:alert(1)">x</a> */})].each do |hidden|
        expect { post.set_field_value('specs', hidden) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('specs')).to be_blank
      end
    end

    # JSON.parse skips a comment, but the string-literal scan reads a quote in it, and its literals
    # shift. The template of the field shows the members of the parse, so the scan reads them too.
    it 'refuses an escaped script member after a quote in a comment' do
      as_user(contributor)
      member = { value: script }.to_json[1...-1]

      [%({/* " */#{member}}), %({"attr":"a", // "\n#{member}}), %({/* "\\x */#{member}})].each do |hidden|
        expect { post.set_field_value('specs', hidden) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('specs')).to be_blank
      end
    end

    # The parse keeps only the last member of a duplicate key. A comment can hold a quote or a literal
    # that does not parse. The scan of the literals skips each comment, as the parse does.
    it 'refuses an escaped script member that a duplicate key hides, with a quote in a comment' do
      as_user(contributor)
      member = { value: script }.to_json[1...-1]

      [%({#{member},"value":"x" /* "\\x" */}), %({/* " */#{member},"value":"x"}),
       %({#{member}, // "\n"value":"x"})].each do |hidden|
        expect { post.set_field_value('specs', hidden) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('specs')).to be_blank
      end
    end

    # The data shortcode shows the stored JSON, where `\"` does not escape the quote. So the quote
    # ends the attribute there, and the text after it becomes an event handler.
    it 'refuses a stored JSON string whose escaped quote ends an attribute' do
      as_user(contributor)
      quoted = %({"attr":"a","value":"<img src=x title=\\"a onerror=alert(1);//\\">"})

      expect { post.set_field_value('specs', quoted) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(post.get_field_value('specs')).to be_blank
    end

    # The template of the field and the_json_field show a member that is an object or an array as
    # Ruby text, which writes each quote of a String in it as `\"`. There the quote ends the
    # attribute, as in the stored JSON. The stored JSON escapes `<`, so only the Ruby text shows the tag.
    it 'refuses an object or an array member whose Ruby text ends an attribute' do
      as_user(contributor)
      tag = '<img src=x title="a onerror=alert(1);//">'

      [{ attr: 'a', value: { x: tag } }.to_json, { attr: 'a', value: [tag] }.to_json].each do |nested|
        expect(nested).not_to include('<')
        expect { post.set_field_value('specs', nested) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('specs')).to be_blank
      end
    end

    it 'stores an object member with allowed markup unchanged' do
      as_user(contributor)
      nested = { attr: 'Color', value: { shade: 'Deep <em>red</em>' } }.to_json

      post.set_field_value('specs', nested)

      expect(post.get_field_value('specs')).to eq(nested)
    end

    # The template of the field translates the value before it parses the JSON.
    it 'refuses an escaped script in a translation of the JSON' do
      as_user(contributor)
      translated = "<!--:en-->#{{ attr: 'Color', value: script }.to_json}<!--:-->"

      expect { post.set_field_value('specs', translated) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(post.get_field_value('specs')).to be_blank
    end

    # Code that saves a pair as a Hash stores it with generate_json, which keeps `<` and writes each
    # quote of an attribute as `\"`. The data shortcode shows that text, so the scan refuses the tag
    # (intended). The to_json form escapes `<`, as the admin form does.
    it 'refuses a Hash pair with a quoted attribute, and stores its to_json form' do
      as_user(contributor)
      pair = { attr: 'Link', value: '<a href="https://example.com/">Shop</a>' }

      expect { post.set_field_value('specs', pair) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      post.set_field_value('specs', pair.to_json)

      expect(post.get_field_value('specs')).to eq(pair.to_json)
    end

    it 'stores a benign translated pair and a pair with a quoted attribute unchanged' do
      as_user(contributor)
      translated = { en: { attr: 'Color', value: 'Red' }.to_json, es: { attr: 'Color', value: 'Rojo' }.to_json }

      [translated.to_translate,
       { attr: 'Link', value: '<a href="https://example.com/">Shop</a>' }.to_json].each do |value|
        post.set_field_value('specs', value)

        expect(post.get_field_value('specs')).to eq(value)
      end
    end

    it 'stores a benign JSON-array value unchanged' do
      as_user(contributor)
      arr = [{ attr: 'a', value: 'plain' }, { attr: 'b', value: 'Deep <em>red</em>' }].to_json

      post.set_field_value('specs', arr)

      expect(post.get_field_value('specs')).to eq(arr)
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

  describe 'persistence semantics of the gate' do
    it 'keeps the previously stored value when a new value is refused (M7 atomicity)' do
      as_user(contributor)
      post.set_field_value('body', '<p>keep me</p>')

      expect { post.set_field_value('body', script) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(post.reload.get_field_value('body')).to eq('<p>keep me</p>')
    end

    it 'keeps the stored value when the caller rescues the error inside its transaction' do
      as_user(contributor)
      post.set_field_value('body', '<p>keep me</p>')

      ActiveRecord::Base.transaction do
        post.set_field_value('body', script)
      rescue ActiveRecord::RecordInvalid
        nil
      end

      expect(post.reload.get_field_value('body')).to eq('<p>keep me</p>')
    end

    it 'stores no value of a failed call when the caller saves the post after the error' do
      as_user(contributor)
      post.set_field_value('body', '<p>keep me</p>')

      expect { post.set_field_value('body', ['<p>first</p>', script]) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(post.save).to be(true)
      expect(post.reload.get_field_values('body')).to eq(['<p>keep me</p>'])
    end

    # After the failed call, set_field_value resets the association of the post, which removes each
    # unsaved row. It then puts back the row that the caller built before the call.
    it 'keeps the row that the caller built when set_field_value fails for a list' do
      as_user(contributor)
      post.set_field_value('body', '<p>keep me</p>')
      post.custom_field_values.build(custom_field_id: post.get_field_object('body').id, custom_field_slug: 'body',
                                     value: '<p>built</p>', group_number: 5)

      expect { post.set_field_value('body', ['<p>first</p>', script]) }.to raise_error(ActiveRecord::RecordInvalid)

      expect(post.save).to be(true)
      expect(post.reload.custom_field_values.pluck(:value)).to contain_exactly('<p>keep me</p>', '<p>built</p>')
    end

    it 'refuses a dangerous value written through update_field_value (M5)' do
      as_user(contributor)
      post.set_field_value('body', '<p>ok</p>')

      expect(post.update_field_value('body', script)).to be(false)
      expect(post.reload.get_field_value('body')).to eq('<p>ok</p>')
    end

    # update_field_value stores a Hash as JSON. JSON keeps the markup, so the gate refuses it.
    it 'refuses a Hash with a dangerous value written through update_field_value' do
      as_user(contributor)
      post.set_field_value('body', '<p>ok</p>')

      expect(post.update_field_value('body', { html: script })).to be(false)

      expect(post.reload.get_field_value('body')).to eq('<p>ok</p>')
    end

    # update_field_value updates the stored row, and puts only a saved value in the row that a loaded
    # association holds. So a refused update changes no row, and the readers read the stored value.
    it 'keeps the stored value in a loaded association after a refused update_field_value' do
      as_user(contributor)
      post.set_field_value('body', '<p>ok</p>')
      post.custom_field_values.load

      expect(post.update_field_value('body', script)).to be(false)
      expect(post.get_field_value('body')).to eq('<p>ok</p>')
      expect(post.custom_field_values.find { |row| row.custom_field_slug == 'body' }).not_to be_changed
    end

    # Audit M8: the admin form round-trips every value and set_field_values delete/recreates them
    # all, so an unchanged pre-gate value must not fail the whole save on an unrelated edit.
    it 'does not re-gate an unchanged legacy value on an unrelated edit (M8)' do
      post.set_field_value('body', '<p>ok</p>')
      post.custom_field_values.find_by(custom_field_slug: 'body')
          .update_column(:value, script) # rubocop:disable Rails/SkipsModelValidations -- simulate pre-gate data

      as_user(contributor)
      datas = { '0' => {
        'body' => { id: post.get_field_object('body').id, values: { '0' => script } },
        'note' => { id: post.get_field_object('note').id, values: { '0' => 'edited note' } }
      } }

      expect { post.set_field_values(datas) }.not_to raise_error
      expect(post.get_field_value('note')).to eq('edited note')
      expect(post.get_field_value('body')).to eq(script)
    end

    it 'refuses a later change of a legacy value that set_field_values created again' do
      post.set_field_value('body', '<p>ok</p>')
      post.custom_field_values.find_by(custom_field_slug: 'body')
          .update_column(:value, script) # rubocop:disable Rails/SkipsModelValidations -- simulate pre-gate data

      as_user(contributor)
      post.set_field_values({ '0' => { 'body' => { id: post.get_field_object('body').id,
                                                   values: { '0' => script } } } })
      row = post.custom_field_values.find { |value| value.custom_field_slug == 'body' }

      expect(row.update(value: "#{script}<p>more</p>")).to be(false)
      expect(row.errors[:base].join).to match(/not allowed/)
      expect(post.reload.get_field_value('body')).to eq(script)
    end

    it 'still refuses a legacy value that the author actually changes (M8 does not weaken the gate)' do
      post.set_field_value('body', '<p>ok</p>')

      as_user(contributor)
      datas = { '0' => {
        'body' => { id: post.get_field_object('body').id, values: { '0' => script } }
      } }

      expect { post.set_field_values(datas) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # The settings and custom_fields permissions give a role the trust of an administrator. So a holder
  # of one of them is trusted for the fields of each owner that is not a post, in the current site. A
  # holder of `theme_settings` is trusted for the fields of a theme, the permission of the theme
  # settings save. The fields of a post follow the permission of the post body.
  describe 'trust for the fields of owners that are not a post' do
    let(:manager_role) { site.user_roles.create!(name: 'Manager', slug: 'field_mgr') }
    let(:manager) { create(:user, role: manager_role.slug, site: site) }
    let(:theme) { site.decorate.get_theme }
    let(:category) do
      post_type.add_custom_field_group({ name: 'Cat', slug: 'cat-extra' }, 'Category')
               .add_manual_field({ name: 'Cat note', slug: 'cat_note' }, { field_key: 'text_box' })
      post_type.categories.create!(name: 'Cat', slug: 'cat-trust')
    end

    before do
      site.custom_field_groups.create!(name: 'Site', slug: '_site-extra', object_class: 'Site', objectid: site.id)
          .add_manual_field({ name: 'Site note', slug: 'site_note' }, { field_key: 'text_box' })
      theme.add_field_group({ name: 'Theme', slug: '_theme-extra' })
           .add_manual_field({ name: 'Theme note', slug: 'theme_note' }, { field_key: 'text_box' })
    end

    def grant(*permissions)
      manager_role.set_meta("_manager_#{site.id}", permissions.index_with(1))
      as_user(manager)
    end

    %w[settings custom_fields].each do |permission|
      it "stores a script site, theme and category field value for a holder of #{permission}" do
        grant(permission)

        site.set_field_value('site_note', script)
        theme.set_field_value('theme_note', script)
        category.set_field_value('cat_note', script)

        expect(site.get_field_value('site_note')).to eq(script)
        expect(theme.get_field_value('theme_note')).to eq(script)
        expect(category.get_field_value('cat_note')).to eq(script)
      end

      it "refuses a script post field value for a holder of #{permission}" do
        grant(permission)

        expect { post.set_field_value('note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('note')).to be_blank
      end
    end

    # A row names its owner class by a short name, such as 'Post'. The trust check must read the Camaleon
    # post, also when the host app has its own Post model.
    context 'when the host app has a top-level Post model' do
      before do
        host_post = Class.new(ActiveRecord::Base) # rubocop:disable Rails/ApplicationRecord
        host_post.table_name = CamaleonCms::Post.table_name
        stub_const('Post', host_post)
      end

      it 'refuses a script post field value for a holder of settings' do
        grant('settings')

        expect { post.set_field_value('note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
        expect(post.get_field_value('note')).to be_blank
      end

      it 'stores a script post field value for a holder of post_content_unfiltered_html' do
        manager_role.set_meta("_post_type_#{site.id}", edit: [post_type.id],
                                                       post_content_unfiltered_html: [post_type.id])
        as_user(manager)

        post.set_field_value('note', script)

        expect(post.get_field_value('note')).to eq(script)
      end
    end

    it 'stores a script theme field value for a holder of theme_settings' do
      grant('theme_settings')

      theme.set_field_value('theme_note', script)

      expect(theme.get_field_value('theme_note')).to eq(script)
    end

    it 'refuses a script site or category field value for a holder of theme_settings' do
      grant('theme_settings')

      expect { site.set_field_value('site_note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect { category.set_field_value('cat_note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(site.get_field_value('site_note')).to be_blank
      expect(category.get_field_value('cat_note')).to be_blank
    end

    it 'refuses a script field value of another site for a holder of settings' do
      other = CamaleonCms::Site.create!(name: 'Other', slug: 'other-trust', taxonomy: 'site')
      other.custom_field_groups.create!(name: 'Other', slug: '_other-extra', object_class: 'Site', objectid: other.id)
           .add_manual_field({ name: 'Other note', slug: 'other_note' }, { field_key: 'text_box' })
      grant('settings')

      expect { other.set_field_value('other_note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
    end

    it 'refuses a script theme field value of another site for a holder of settings and theme_settings' do
      other = CamaleonCms::Site.create!(name: 'Other', slug: 'other-theme-trust', taxonomy: 'site')
      other_theme = other.get_theme
      other_theme.add_field_group({ name: 'Other theme', slug: '_other-theme-extra' })
                 .add_manual_field({ name: 'Other theme note', slug: 'other_theme_note' }, { field_key: 'text_box' })
      grant('settings', 'theme_settings')

      expect { other_theme.set_field_value('other_theme_note', script) }
        .to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(other_theme.get_field_value('other_theme_note')).to be_blank
    end

    it 'refuses a script site or theme field value without a request context' do
      expect { site.set_field_value('site_note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect { theme.set_field_value('theme_note', script) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
    end
  end

  # set_field_values took custom_field_id straight from the client-supplied values[:id]. A forged id
  # of another kind made the gate read the wrong field_key and use the wrong rules. The id is now
  # resolved from the trusted slug instead.
  describe 'forged custom_field_id' do
    # A text_box value is scanned as stored. A field_attrs value is scanned by its decoded JSON members,
    # and the stored JSON escapes `<` as <. So the forged id of a text_box would pass the script.
    it 'keeps the member scan of a field_attrs slug when the client forges the custom_field_id of a text_box' do
      as_user(contributor)
      forged_id = post.get_field_object('note').id
      escaped = { attr: 'Color', value: script }.to_json
      expect(escaped).not_to include('<')

      datas = { '0' => { 'specs' => { id: forged_id, values: { '0' => escaped } } } }

      expect { post.set_field_values(datas) }.to raise_error(ActiveRecord::RecordInvalid, /not allowed/)
      expect(post.custom_field_values.where(custom_field_slug: 'specs')).not_to exist
    end

    it 'keeps the URL rule of a url slug when the client forges the custom_field_id of a text_box' do
      as_user(contributor)
      forged_id = post.get_field_object('note').id

      datas = { '0' => { 'link' => { id: forged_id, values: { '0' => 'javascript:alert(1)' } } } }

      expect { post.set_field_values(datas) }.to raise_error(ActiveRecord::RecordInvalid, /script-capable URL/)
      expect(post.custom_field_values.where(custom_field_slug: 'link')).not_to exist
    end

    it 'records the value against the field the slug names, ignoring the forged id' do
      as_user(contributor)
      forged_id = post.get_field_object('body').id # an unrelated (editor) field

      post.set_field_values('0' => { 'note' => { id: forged_id, values: { '0' => 'plain note' } } })

      row = post.custom_field_values.find_by(custom_field_slug: 'note')
      expect(row.custom_field_id).to eq(post.get_field_object('note').id)
    end
  end
end
