# frozen_string_literal: true

require 'rails_helper'

# The gate in `AdminFormsController` and `ContactFormControllerConcern` is the *only* thing standing
# between authored content and a page that renders it verbatim. These examples cover the three ways a
# gate like that stops being sound, each of which produced a working exploit in review:
#
#   1. It validates a different string than the renderer emits. Every gated value passes through
#      `String#translate`, which selects a locale substring and deletes the `<!--:xx-->` markers, so a
#      payload can be split across a marker and reassembled after the check has run.
#   2. It assumes the shape of `params`. The client picks that shape, and `try(:[], k)` on a String
#      reaches `String#[]` — substring search — which returns nil and reads as "safe".
#   3. It asks the wrong question. `sanitize(v) != v` tests whether a value is *spelled* the way
#      Nokogiri spells it, not whether it is dangerous, so it refused ordinary prose while a value
#      the sanitizer merely reformatted looked identical to one it had gutted.
RSpec.describe 'Security: contact form gate soundness', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:form) { current_site.contact_forms.create!(name: 'Contact', slug: 'contact') }

  before do
    current_site.plugins.where(slug: 'cama_contact_form').first_or_create(set_meta: { status: 'active' })
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def role_with(manager_meta, slug)
    role = current_site.user_roles.create!(name: slug, slug: slug)
    role.set_meta("_manager_#{current_site.id}", manager_meta)
    create(:user, role: slug, site: current_site)
  end

  def publish(target = form)
    current_site.the_post('sample-post').update!(content: "[forms slug='#{target.slug}']")
  end

  def render_page
    get '/sample-post'
    Nokogiri::HTML5.parse(response.body)
  end

  def save(params_override)
    patch "/admin/plugins/cama_contact_form/admin_forms/#{form.id}", params: {
      plugins_cama_contact_form_cama_contact_form: { name: 'Contact', slug: 'contact' },
      railscf_mail: { to: 'a@b.c', subject: 's', body: 'b' },
      railscf_message: {},
      railscf_form_button: { name_button: 'Send' }
    }.merge(params_override)
    form.reload
  end

  def field(overrides = {})
    { c1: { label: 'Name', field_type: 'text', cid: 'c1', required: 'false',
            field_options: { template: '<div>[ci]</div>' } }.deep_merge(overrides) }
  end

  # --- 1. The gate must judge the string the renderer emits ------------------
  describe 'values are judged as the renderer will emit them' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # `</tex<!--:en-->tarea>` contains no `</textarea` until `translate` deletes the marker.
    it 'refuses a payload split across a translation marker in a default value' do
      save(fields: { c1: { label: 'M', field_type: 'paragraph', cid: 'c1', required: 'false',
                           default_value: "<!--:en-->\n</tex<!--:en-->tarea><img src=x onerror=alert(1)>",
                           field_options: { template: '<div>[ci]</div>' } } })

      expect(form.fields).to be_blank
    end

    it 'refuses a response message that reassembles into an unterminated attribute' do
      save(railscf_message: { mail_sent_ok: '<!--:en--><a title="<!--:--><!--:es-->"></a><!--:-->' })

      expect(form.the_settings[:railscf_message]).to be_blank
    end

    # `cama_sanitize_translatable` shields every `<!--` so locale markers survive the sanitizer, which
    # is precisely why a bare `<!--` reaches the page. Emitted into a label it comments out everything
    # to the next `-->` — the remaining fields, the submit button, the footer.
    it 'refuses an unterminated HTML comment that would swallow the rest of the page' do
      save(fields: field(label: 'Name <!--'))

      expect(form.fields).to be_blank
    end

    it 'still accepts a well-formed translation marker' do
      save(fields: field(label: '<!--:en-->Name<!--:--><!--:es-->Nombre<!--:-->'))

      expect(form.fields.first[:label]).to include('Nombre')
    end
  end

  # --- 2. The gate must not assume the shape of params ----------------------
  describe 'params of an unexpected shape' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # A scalar where a Hash belongs used to slip past unchecked — `"…".try(:[], "name_button")` is
    # substring search — and then raise TypeError on every public page, with the save reported as a
    # success and no way back but a database edit.
    it 'refuses a scalar where the submit button settings belong' do
      save(railscf_form_button: '<img src=x onerror=alert(1)>', fields: field)

      expect(form.the_settings[:railscf_form_button]).to be_blank
    end

    it 'refuses a scalar where the mail settings belong' do
      save(railscf_mail: 'x', fields: field)

      expect(form.the_settings[:railscf_mail]).to be_blank
    end

    it 'refuses an option that is a bare string rather than a hash' do
      save(fields: { c1: { label: 'P', field_type: 'radio', cid: 'c1', required: 'false',
                           field_options: { options: { '0' => '<script>alert(1)</script>' } } } })

      expect(form.fields).to be_blank
    end

    it 'refuses an option carrying no label at all' do
      save(fields: { c1: { label: 'P', field_type: 'radio', cid: 'c1', required: 'false',
                           field_options: { options: { '0' => { checked: 'false' } } } } })

      expect(form.fields).to be_blank
    end

    it 'refuses an array-valued template, which is sanitize-stable but not a string' do
      save(fields: { c1: { label: 'N', field_type: 'text', cid: 'c1', required: 'false',
                           field_options: { template: ['<div>[ci]</div>'] } } })

      expect(form.fields).to be_blank
    end

    it 'does not raise when a field arrives without field_options' do
      save(fields: { c1: { label: 'N', field_type: 'text', cid: 'c1', required: 'false' } })

      expect(response).not_to have_http_status(:error)
    end

    # `[1,2]` is valid JSON but not an object. The renderer's `rescue {}` binds only to `JSON.parse`,
    # so it reached `{id: cid}.merge([1,2])` and raised TypeError on every visit.
    it 'refuses field_attributes that parse to something other than an object' do
      save(fields: field(field_options: { field_attributes: '[1,2]' }))

      expect(form.fields).to be_blank
    end

    it 'still ignores field_attributes that are not JSON at all, as the renderer does' do
      save(fields: field(field_options: { field_attributes: 'not json' }))

      expect(form.fields).to be_present
    end
  end

  # --- 3. The gate must refuse danger, not unfamiliar spelling ---------------
  describe 'ordinary authored content is accepted' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # Each of these was refused by `sanitize(v) != v`, which is a test of spelling rather than safety.
    {
      'an ampersand in prose' => 'Tom & Jerry',
      'a non-breaking space entity' => 'Please wait&nbsp;here',
      'a copyright entity' => '&copy; 2026 Acme',
      'an em dash entity' => 'Acme &mdash; est. 1999',
      'a less-than sign in prose' => 'Price < 100',
      'a self-closing break' => 'One<br/>Two',
      'uppercase tags' => '<UL><LI>One</LI></UL>',
      'single-quoted attributes' => "<div class='intro'>Hello</div>",
      'a URL with a query string' => 'See https://example.com/a?b=1&c=2'
    }.each do |description, value|
      it "accepts #{description}" do
        save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', after_html: value }, fields: field)

        expect(form.the_settings[:railscf_mail][:after_html]).to eq(value)
      end
    end

    # The plugin's own default field template — shown to authors as the editor placeholder — was
    # refused, because Rails' safe list is tuned for prose and drops `<label>`.
    it "accepts the plugin's own default field template" do
      default_template = Plugins::CamaContactForm::CamaContactForm.field_template
      save(fields: field(field_options: { template: default_template }))

      expect(form.fields.first[:field_options][:template]).to eq(default_template)
    end

    it 'accepts a table, a label and a fieldset in a template' do
      markup = '<fieldset><legend>Contact</legend><label for="c1">[label ci]</label>[ci]</fieldset>'
      save(fields: field(field_options: { template: markup }))

      expect(form.fields.first[:field_options][:template]).to eq(markup)
    end

    {
      'a script element' => '<script>alert(1)</script>',
      'an event handler' => '<div onload="alert(1)">x</div>',
      'a javascript URL' => '<a href="javascript:alert(1)">x</a>',
      'an iframe' => '<iframe src="//evil"></iframe>'
    }.each do |description, payload|
      it "still refuses #{description}" do
        save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', after_html: payload }, fields: field)

        expect(form.the_settings[:railscf_mail]).to be_blank
      end
    end
  end

  # --- field_attributes: a name can be script without escaping anything ------
  describe 'field_attributes names that are themselves dangerous' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # `formaction` on the submit button fires on the click the form exists to receive. It matches the
    # attribute-name pattern, is not an `on*` handler, and carries no double quote.
    it 'refuses a javascript: URL in formaction' do
      save(fields: field(field_options: { field_attributes: '{"formaction": "javascript:alert(1)"}' }))

      expect(form.fields).to be_blank
    end

    {
      'an embedded tab' => '{"href": "java\tscript:alert(1)"}',
      'leading space and uppercase' => '{"src": " JAVASCRIPT:alert(1)"}',
      'an HTML entity' => '{"formaction": "&#106;avascript:alert(1)"}'
    }.each do |description, payload|
      it "refuses a javascript: URL written with #{description}" do
        save(fields: field(field_options: { field_attributes: payload }))

        expect(form.fields).to be_blank
      end
    end

    it 'refuses an inline style, which can cover the viewport' do
      save(fields: field(field_options: { field_attributes: '{"style": "position:fixed;inset:0"}' }))

      expect(form.fields).to be_blank
    end

    it 'accepts an ordinary relative URL in the same attribute' do
      save(fields: field(field_options: { field_attributes: '{"formaction": "/contact/send"}' }))

      expect(form.fields).to be_present
    end
  end

  # --- the gate must not be a lever for burning CPU -------------------------
  describe 'response messages are bounded' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # Each value costs a sanitizer parse, so taking railscf_message from params wholesale let the
    # submitter choose the number of parses: ~4090 keys fit inside Rack's parameter cap.
    it 'stores only the known message keys, whatever else is submitted' do
      junk = (1..300).to_h { |i| ["junk_#{i}", "<div>#{'x' * 50}</div>"] }
      save(railscf_message: junk.merge('mail_sent_ok' => 'Thanks'), fields: field)

      stored = form.the_settings[:railscf_message]
      expect(stored[:mail_sent_ok]).to eq('Thanks')
      expect(stored.keys.map(&:to_s).grep(/junk/)).to be_empty
    end

    it 'still refuses a payload in a known message key' do
      save(railscf_message: { 'invalid_email' => '<script>alert(1)</script>' }, fields: field)

      expect(form.the_settings[:railscf_message]).to be_blank
    end
  end

  # `<option>` is NOT text-only: script inside one survives parsing and executes. The position is
  # gated like any other, and must not be assumed inert.
  describe 'dropdown option labels' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    it 'refuses script in a dropdown option label' do
      save(fields: { c1: { label: 'Choose', field_type: 'dropdown', cid: 'c1', required: 'false',
                           field_options: { options: { '0' => { label: '<script>alert(1)</script>',
                                                                checked: 'false' } } } } })

      expect(form.fields).to be_blank
    end
  end

  # --- 4. The oracle only sees what the safe list removed -------------------
  #
  # Comparing `sanitize(x)` against the reserialized `x` cancels out spelling differences, which is
  # what makes ordinary prose acceptable. But it is blind to anything BOTH sides discard, and the
  # HTML5 parser discards plenty when it is handed a fragment at EOF.
  describe 'markup the parser drops before the sanitizer can see it' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # The first three leave a tag open: both sides serialize to "" because the parser drops it at
    # EOF, so they compare equal. The browser is not at EOF — it finishes the `x` attribute at the
    # next quote in the document and the div carries a live handler.
    #
    # The last two are foster-parented away before the sanitizer ever sees them, so both sides yield
    # bare text. Rendered into a page that has opened table context — the author's own `<table>`, or
    # a table in the post the shortcode sits in — they become live elements.
    {
      'an unterminated attribute' => '<div class="a" onmouseover="alert(1)" x="',
      'an unterminated tag' => '<img src=x onerror=alert(1) x="',
      'a bare tag open' => '<span title="',
      'a table cell, which parses to nothing on its own' => '<td onmouseover="alert(1)">Hover me</td>',
      'a table row, which parses to nothing on its own' => '<tr onclick="alert(1)"><td>x</td></tr>'
    }.each do |description, payload|
      it "refuses #{description}" do
        save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', previous_html: payload },
             fields: field)

        expect(form.the_settings[:railscf_mail]).to be_blank
      end
    end

    it 'still accepts a whole, well-formed table' do
      markup = '<table><thead><tr><th>H</th></tr></thead><tbody><tr><td>C</td></tr></tbody></table>'
      save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', after_html: markup }, fields: field)

      expect(form.the_settings[:railscf_mail][:after_html]).to eq(markup)
    end

    # `rel="opener"` is the explicit opt-back-in to the `window.opener` handle that browsers disable
    # for `target="_blank"`. Rails omits both attributes from its safe list for exactly this reason;
    # an earlier revision added them back for layout convenience.
    it 'refuses a link that re-enables window.opener' do
      save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b',
                           after_html: '<a href="https://evil.tld" target="_blank" rel="opener">Brochure</a>' },
           fields: field)

      expect(form.the_settings[:railscf_mail]).to be_blank
    end
  end

  # --- the gate must not refuse what authors actually write -----------------
  describe 'ordinary authored markup and prose are accepted' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # `data-` and `aria-` are an open set, so they cannot be listed; they are admitted by shape. A
    # Bootstrap wrapper and an accessible template are most of what `template` exists for, and the
    # editor's own Field Attributes placeholder advertises `data-my-attr`.
    {
      'a data- attribute' => "<div data-toggle='collapse' data-target='#x'>[ci]</div>",
      'an aria- attribute' => "<div aria-label='Contact'>[ci]</div>",
      'a role' => "<div role='form'>[ci]</div>",
      'a tabindex' => "<div tabindex='0'>[ci]</div>"
    }.each do |description, template|
      it "accepts a template carrying #{description}" do
        save(fields: field(field_options: { template: template }))

        expect(form.fields.first[:field_options][:template]).to eq(template)
      end
    end

    # A translated value is `<!--:en-->…<!--:-->`, so the closing marker follows whatever the author
    # wrote. Counting every `<` as a tag open meant a comparison anywhere in the text put the closing
    # marker "inside a tag" and refused the save, naming markup that was not there.
    it 'accepts a translated value containing a comparison' do
      save(railscf_message: { mail_sent_ok: '<!--:en-->Only 5 < 10 left<!--:--><!--:es-->Solo 5 < 10<!--:-->' },
           fields: field)

      expect(form.the_settings[:railscf_message][:mail_sent_ok]).to include('5 < 10')
    end

    # An ASCII arrow is not an unbalanced comment. Comparing `<!--` and `-->` counts refused it.
    it 'accepts prose containing an arrow' do
      save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', after_html: 'Step 1 --> Step 2' },
           fields: field)

      expect(form.the_settings[:railscf_mail][:after_html]).to eq('Step 1 --> Step 2')
    end
  end

  # --- the e-mail is a markup sink too --------------------------------------
  describe 'mail values that reach the notification e-mail as markup' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # `mailer.html.erb` is `<h2><%= raw @subject %></h2>` above `<%= raw @html %>`, so the subject is
    # as raw a sink as the body. It was in no gate list at all.
    it 'refuses script in the mail subject' do
      save(railscf_mail: { to: 'a@b.c', subject: '<script>alert(1)</script>', body: 'b' }, fields: field)

      expect(form.the_settings[:railscf_mail]).to be_blank
    end

    it 'refuses script in the answer subject' do
      save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b',
                           subject_answer: '<img src=x onerror=alert(1)>' },
           fields: field)

      expect(form.the_settings[:railscf_mail]).to be_blank
    end
  end

  # --- a form with no settings at all must still render ---------------------
  describe 'a form saved without its settings containers' do
    # `fix_save_settings` seeds `settings` to `{}`, and a partial update can leave any container
    # unset. The shortcode read straight through `the_settings[:railscf_mail][:previous_html]`, so
    # every visit raised NoMethodError until someone edited the database.
    it 'renders the public page instead of raising' do
      bare = current_site.contact_forms.create!(name: 'Bare', slug: 'bare')
      current_site.the_post('sample-post').update!(content: "[forms slug='bare']")

      expect { get '/sample-post' }.not_to raise_error
      expect(response).to have_http_status(:ok)
      expect(bare.reload.mail_settings).to eq({})
    end
  end

  # --- entity-encoded URL schemes -------------------------------------------
  describe 'field_attributes URL schemes' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    # `CGI.unescapeHTML` knows the five legacy entities and numeric references, and nothing else --
    # so `javascript&colon;` walked straight past it while the HTML parser resolves it to
    # `javascript:`. The parser is the authority on that question, so it is the one asked.
    {
      'a named entity for the colon' => '{"formaction": "javascript&colon;alert(1)"}',
      'a named entity for a tab' => '{"formaction": "java&Tab;script:alert(1)"}',
      'a named entity for a newline' => '{"formaction": "java&NewLine;script:alert(1)"}',
      'a numeric entity' => '{"formaction": "&#106;avascript:alert(1)"}',
      'no encoding at all' => '{"formaction": "javascript:alert(1)"}'
    }.each do |description, payload|
      it "refuses a script URL written with #{description}" do
        save(fields: field(field_options: { field_attributes: payload }))

        expect(form.fields).to be_blank
      end
    end

    it 'still accepts an ordinary URL' do
      save(fields: field(field_options: { field_attributes: '{"formaction": "/contact"}' }))

      expect(form.fields.first[:field_options][:field_attributes]).to eq('{"formaction": "/contact"}')
    end
  end

  # --- structural rules must not lock legitimate forms out ------------------
  describe 'structural allowlists' do
    let(:user) { create(:user, role: 'admin', site: current_site) }

    before { sign_in_as(user, site: current_site) }

    # `select` is the legacy spelling of `dropdown`, still handled by the editor and the renderer.
    # Omitting it made any form holding one permanently unsaveable by anybody, administrators
    # included, with a message naming no field.
    it 'accepts the legacy select field type' do
      save(fields: { c1: { label: 'P', field_type: 'select', cid: 'c1', required: 'false',
                           field_options: { options: { '0' => { label: 'One', checked: 'false' } } } } })

      expect(form.fields).to be_present
    end

    # Every one of these reached the renderer from a save the author was told had succeeded, and
    # every one of them is a 500 on every visit to the page until someone edits the database.
    it 'refuses a required flag that is not a scalar' do
      save(fields: field(required: { x: '1' }))

      expect(form.fields).to be_blank
    end

    it 'refuses a choice field with no options at all' do
      save(fields: { c1: { label: 'P', field_type: 'radio', cid: 'c1', required: 'false',
                           field_options: {} } })

      expect(form.fields).to be_blank
    end

    it 'refuses a field that is not a hash rather than silently dropping it' do
      save(fields: { c1: 'junk' })

      expect(form.fields).to be_blank
      expect(flash[:error]).to be_present
    end

    it 'refuses an empty fields parameter without raising' do
      expect { save(fields: '') }.not_to raise_error

      expect(form.fields).to be_blank
      expect(flash[:error]).to be_present
    end

    it 'refuses a settings container that is a scalar' do
      save(railscf_mail: '')

      expect(form.the_settings).to be_blank
    end

    it 'refuses a nested mail value that is not a scalar' do
      save(railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', to_answer: { x: 'y' } })

      expect(form.the_settings).to be_blank
    end
  end

  # --- caps: the number and size of parses must not be chosen by the caller -
  describe 'gate cost is bounded' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    it 'refuses more options than a form can plausibly carry' do
      options = (0..120).to_h { |i| [i.to_s, { label: "Option #{i}", checked: 'false' }] }
      save(fields: { c1: { label: 'P', field_type: 'radio', cid: 'c1', required: 'false',
                           field_options: { options: options } } })

      expect(form.fields).to be_blank
    end

    it 'refuses more fields than a form can plausibly carry' do
      fields = (0..250).to_h do |i|
        ["c#{i}", { label: 'N', field_type: 'text', cid: "c#{i}", required: 'false', field_options: {} }]
      end
      save(fields: fields)

      expect(form.fields).to be_blank
    end

    it 'refuses a single gated value larger than the cap, without parsing it' do
      save(fields: field(field_options: { template: "<div>[ci]</div>#{'&x' * 40_000}" }))

      expect(form.fields).to be_blank
    end
  end

  # --- the visitor gate --------------------------------------------------
  describe 'visitor submissions of an unexpected shape' do
    def build_form(fields:, slug: 'contact', name: 'Contact')
      current_site.contact_forms.where(slug: slug).first_or_create!(name: name).tap do |f|
        f.update!(value: { fields: fields }.to_json,
                  settings: { 'railscf_mail' => { 'to' => 'o@e.com', 'subject' => 's', 'body' => 'b' },
                              'railscf_message' => {},
                              'railscf_form_button' => { 'name_button' => 'Send' } }.to_json)
      end
    end

    # The submitter chooses their own POST shape. `fields[c1][]=…` arrives as an Array, which the
    # String-only guard skipped entirely — and `Array#to_s` then supplied the double quote that closed
    # the attribute, so the payload needed none of its own. No credentials required.
    it 'refuses an array-shaped value carrying an event handler' do
      f = build_form(fields: [{ label: 'A', field_type: 'text', cid: 'c1', required: 'true', field_options: {} },
                              { label: 'B', field_type: 'text', cid: 'c2', required: 'true', field_options: {} }])
      publish(f)

      post '/plugins/cama_contact_form/save_form',
           params: { id: f.id, fields: { c1: ['x onfocus=alert(1) autofocus'], c2: '' } }
      follow_redirect!
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      expect(input.attributes.keys).not_to include('onfocus', 'autofocus')
      expect(input['value']).to be_blank
    end

    # `save_form` redirects on every path — success, validation failure and content refusal alike —
    # so asserting a redirect asserts nothing. This example must distinguish accepted from refused,
    # which means looking at what was stored. It did not, which is how a regression that refused
    # EVERY checkbox and radio submission shipped with a spec named after it: `Array#to_s` is
    # `inspect`, so `["one"].to_s` carries the double quote the attribute rule was looking for.
    it 'still accepts a legitimate array from a checkboxes field' do
      f = build_form(fields: [{ label: 'Pick', field_type: 'checkboxes', cid: 'c1', required: 'false',
                                field_options: { options: [{ label: 'One', checked: false }] } },
                              { label: 'B', field_type: 'text', cid: 'c2', required: 'false', field_options: {} }])
      publish(f)

      expect do
        post '/plugins/cama_contact_form/save_form', params: { id: f.id, fields: { c1: ['one'], c2: 'hi' } }
      end.to change { f.responses.count }.by(1)

      expect(flash[:contact_form][:error]).to be_blank
    end

    it 'still accepts a radio submission, which also arrives as an array' do
      f = build_form(fields: [{ label: 'Pick', field_type: 'radio', cid: 'c1', required: 'false',
                                field_options: { options: [{ label: 'One', checked: false }] } }])
      publish(f)

      expect do
        post '/plugins/cama_contact_form/save_form', params: { id: f.id, fields: { c1: ['one'] } }
      end.to change { f.responses.count }.by(1)
    end

    # `Array#to_s` on an upload is `inspect`, whose `@original_filename="…"` always carries quotes,
    # so judging the array's own string form refused every submission that attached a file.
    it 'still accepts a file upload' do
      f = build_form(fields: [{ label: 'Doc', field_type: 'file', cid: 'c1', required: 'false',
                                field_options: {} }])
      publish(f)
      upload = Rack::Test::UploadedFile.new(Rails.root.join('../support/fixtures/rails.png'), 'image/png')

      expect do
        post '/plugins/cama_contact_form/save_form', params: { id: f.id, fields: { c1: [upload] } }
      end.to change { f.responses.count }.by(1)
    end

    # A Hash-shaped value skipped the check entirely, and then `Hash#to_s` supplied the quote that
    # closed the attribute — the same bypass as the Array case, one `case` arm away.
    it 'refuses a hash-shaped value carrying an event handler' do
      f = build_form(fields: [{ label: 'A', field_type: 'text', cid: 'c1', required: 'true', field_options: {} },
                              { label: 'B', field_type: 'text', cid: 'c2', required: 'true', field_options: {} }])
      publish(f)

      post '/plugins/cama_contact_form/save_form',
           params: { id: f.id, fields: { c1: { 'onfocus=alert(1) autofocus x' => 'y' }, c2: '' } }
      follow_redirect!
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      expect(input.attributes.keys).not_to include('onfocus', 'autofocus')
      expect(input['value']).to be_blank
    end

    # `find_by_id` returns nil for a deleted or bogus id, and the redisplay guard dereferenced it.
    # Unauthenticated 500.
    it 'does not raise when the form id names no form' do
      expect do
        post '/plugins/cama_contact_form/save_form', params: { id: 999_999, fields: { c1: 'x' } }
      end.not_to raise_error

      expect(response).to have_http_status(:redirect)
    end

    it 'does not raise when the submission carries no fields at all' do
      f = build_form(fields: [{ label: 'A', field_type: 'text', cid: 'c1', required: 'true', field_options: {} }])

      expect { post '/plugins/cama_contact_form/save_form', params: { id: f.id } }.not_to raise_error
    end

    # The gate walks the fields of the form named by params[:id], but the redisplay page hands
    # flash[:values] to every shortcode on it, and cids are `c1, c2, …` in every form. A value cleared
    # as textarea content for one form was being rendered into a value attribute by another.
    it 'does not replay one form\'s values into a different form' do
      target = build_form(slug: 'contact', name: 'A',
                          fields: [{ label: 'A', field_type: 'text', cid: 'c1', required: 'true',
                                     field_options: {} }])
      # `c2` is required and left blank so the submission fails validation — that is the only branch
      # which stashes flash[:values] for redisplay, and therefore the only one that can replay.
      other = build_form(slug: 'other', name: 'B',
                         fields: [{ label: 'B', field_type: 'paragraph', cid: 'c1', required: 'true',
                                    field_options: {} },
                                  { label: 'C', field_type: 'text', cid: 'c2', required: 'true',
                                    field_options: {} }])
      publish(target)

      post '/plugins/cama_contact_form/save_form',
           params: { id: other.id, fields: { c1: 'hello" onfocus="alert(1)" autofocus x="', c2: '' } }
      # Loaded explicitly rather than via follow_redirect!: `redirect_back` has no referer here and
      # falls back to the site root, which renders no form at all — so following it would assert
      # against a page that never had the chance to replay anything.
      get '/sample-post'
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      expect(input).to be_present
      expect(input.attributes.keys).not_to include('onfocus', 'autofocus')
    end
  end
end
