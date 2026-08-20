# frozen_string_literal: true

require 'rails_helper'

# The contact form renders every authored value verbatim, so a trusted author can put markup — or
# script — into a label, a wrapper or a field template and have guests receive it as written.
#
# What makes that safe is this: the admin controller refuses to store content an untrusted author is
# not permitted to write, rather than rewriting it. Stored content therefore always equals authored
# content, and rendering it verbatim introduces nothing the author did not put there.
#
# Without this gate, any role holding `:manage, :plugins` — the only permission the plugin's admin
# controller checks, and not necessarily an administrator — could store script that runs in an
# administrator's session, since the admin panel is same-origin with the public site.
RSpec.describe 'Security: contact form content rejection', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:form) { current_site.contact_forms.create!(name: 'Contact', slug: 'contact') }
  let(:script) { '<p>keep</p><script>alert(1)</script>' }

  before do
    current_site.plugins.where(slug: 'cama_contact_form').first_or_create(set_meta: { status: 'active' })
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  # rubocop:disable Metrics/ParameterLists -- one keyword per gated position, which is the point:
  # each example names only the field it is about and the rest stay at known-good defaults.
  def save_form_with(previous_html: 'Get in touch', template: '<div>[ci]</div>', label: 'Name',
                     description: nil, options: nil, name_button: 'Send', field_class: nil,
                     default_value: nil, cid: 'c1', field_type: 'text', maxlength: nil, field_attributes: nil,
                     messages: {}, recaptcha_site_key: nil)
    field_options = { template: template }
    field_options[:maxlength] = maxlength if maxlength
    field_options[:field_attributes] = field_attributes if field_attributes
    field_options[:description] = description if description
    field_options[:options] = options if options
    field_options[:field_class] = field_class if field_class

    field = { label: label, field_type: field_type, cid: cid, required: 'false', field_options: field_options }
    field[:default_value] = default_value if default_value

    patch "/admin/plugins/cama_contact_form/admin_forms/#{form.id}", params: {
      plugins_cama_contact_form_cama_contact_form: { name: 'Contact', slug: 'contact' },
      railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', previous_html: previous_html, after_html: 'bye' },
      railscf_message: messages,
      railscf_form_button: { name_button: name_button },
      recaptcha_site_key: recaptcha_site_key,
      fields: { c1: field }
    }
    form.reload
  end
  # rubocop:enable Metrics/ParameterLists

  def role_with(manager_meta, slug)
    role = current_site.user_roles.create!(name: slug, slug: slug)
    role.set_meta("_manager_#{current_site.id}", manager_meta)
    create(:user, role: slug, site: current_site)
  end

  # Nothing is stored, so nothing needs re-checking at render, and the author is told which field to
  # fix rather than silently losing their work.
  context 'when the author holds :manage, :plugins but not the unfiltered-HTML grant' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    before { sign_in_as(user, site: current_site) }

    it 'refuses a save carrying script in the wrapper markup, storing nothing' do
      save_form_with(previous_html: script)

      expect(form.the_settings[:railscf_mail]).to be_blank
      expect(flash[:error]).to include('previous_html')
    end

    it 'refuses an event handler in a field template' do
      save_form_with(template: '<div onload="alert(1)">[ci]</div>')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('template')
    end

    it 'refuses script in a field label' do
      save_form_with(label: '<strong>Name</strong><script>alert(1)</script>')

      expect(form.fields).to be_blank
    end

    it 'refuses script in a field description' do
      save_form_with(description: '<em>hint</em><script>alert(1)</script>')

      expect(form.fields).to be_blank
    end

    it 'refuses script in an option label' do
      save_form_with(options: { '0' => { label: '<b>Yes</b><script>alert(1)</script>', checked: 'false' } })

      expect(form.fields).to be_blank
    end

    it 'refuses script in the submit button label' do
      save_form_with(name_button: 'Send<script>alert(1)</script>')

      expect(form.the_settings[:railscf_form_button]).to be_blank
    end

    # An attribute position fails differently: a double quote closes the attribute early, and an HTML
    # sanitizer would not notice because there is no tag to strip.
    it 'refuses a double quote in a field class, which would close the attribute' do
      save_form_with(field_class: 'form-control" onfocus="alert(1)')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('field_class')
    end

    it 'refuses a double quote in a default value' do
      save_form_with(default_value: 'x" onfocus="alert(1)')

      expect(form.fields).to be_blank
    end

    # The message has to name the rule that actually refused the value, not a generic one. An author
    # who typed `btn "primary"` into Custom Class and is told it "contains HTML" goes looking for
    # markup that is not there, and is pointed at a permission that would not have applied.
    describe 'the refusal names the rule that fired' do
      it 'says double quote when the quote rule refused it' do
        save_form_with(field_class: 'btn "primary"')

        expect(flash[:error]).to include('double quote')
        expect(flash[:error]).not_to include('contains HTML')
      end

      it 'says HTML when the markup rule refused it' do
        save_form_with(previous_html: '<script>alert(1)</script>')

        expect(flash[:error]).to include('HTML')
      end

      # `style` is refused for its name, not for a quote it does not contain -- and no amount of
      # removing quotes from valid JSON would ever satisfy the old message.
      it 'says attribute when field_attributes was refused for a name' do
        save_form_with(field_attributes: '{"style": "color: red;"}')

        expect(flash[:error]).to include('attribute')
        expect(flash[:error]).not_to include('double quote')
      end

      # `label` reaches both positions, so it can be refused by either rule.
      it 'says double quote when a label carries one' do
        save_form_with(label: 'Your "name"')

        expect(flash[:error]).to include('double quote')
      end
    end

    # A value is only safe against the position it actually renders in, and default_value's position
    # follows its field type: a paragraph redisplays it as textarea content, where a double quote is
    # ordinary prose and `</textarea` is the only way out. Judging it by the attribute rule let a
    # payload carrying no quote at all through to the page.
    it 'refuses a default value that would close the textarea of a paragraph field' do
      save_form_with(field_type: 'paragraph', default_value: '</textarea><script>alert(1)</script>')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('default_value')
    end

    it 'accepts a quote in a paragraph default value, which is prose in a textarea' do
      save_form_with(field_type: 'paragraph', default_value: 'He said "hello" & left')

      expect(form.fields.first[:default_value]).to eq('He said "hello" & left')
    end

    # The template is authored too, so a template of `<div title="[descr ci]">` used to relocate the
    # description into an attribute -- and a single-quoted `<div class='[descr ci]'>` did the same
    # for a value carrying only an apostrophe, which no rule looked for. The position is now fixed
    # rather than inferred: a template that puts a placeholder inside a tag is refused outright, for
    # everyone, so every substituted value is element content and the quote rules describe the
    # positions the renderer actually writes.
    it 'refuses a template that puts a placeholder inside a tag, double-quoted' do
      save_form_with(template: '<div title="[descr ci]">[ci]</div>')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('template')
    end

    it 'refuses a template that puts a placeholder inside a single-quoted attribute' do
      save_form_with(template: "<div class='[label ci]'>[ci]</div>")

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('template')
    end

    # And with the position fixed, a quote in a description is ordinary prose again.
    it 'accepts a double quote in a description, which can only be element content' do
      save_form_with(description: 'He said "hello" to me')

      expect(form.fields.first[:field_options][:description]).to eq('He said "hello" to me')
    end

    # `onfocus` is a well-formed attribute name carrying a quote-free value, so it escapes nothing --
    # it simply *is* script. Neither the name-shape check nor the quote check can see it.
    it 'refuses a field_attributes key that is an event handler' do
      save_form_with(field_attributes: '{"onfocus": "alert(1)"}')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('field_attributes')
    end

    it 'refuses an event-handler key whatever its case' do
      save_form_with(field_attributes: '{"OnMouseOver": "alert(1)"}')

      expect(form.fields).to be_blank
    end

    # The rule is a blunt `on` prefix, as in every HTML sanitizer, so a custom attribute named `one`
    # is collateral. Asserted rather than left implicit: it is a deliberate trade, not an oversight,
    # and the alternative — a list of known handler names — fails open as the platform adds more.
    it 'refuses an ordinary attribute whose name merely begins with those two letters' do
      save_form_with(field_attributes: '{"one": "1"}')

      expect(form.fields).to be_blank
    end

    it 'accepts the data- and aria- attributes an author would actually reach for' do
      save_form_with(field_attributes: '{"data-one": "1", "aria-label": "Name", "placeholder": "Jo"}')

      expect(form.fields.first[:field_options][:field_attributes]).to include('data-one')
    end

    # railscf_message values are authored prose that the front controller joins into
    # flash[:contact_form], which the frontend flash partial renders with `raw`. They reach a guest
    # on both the failure and the success path.
    it 'refuses script in the validation-failure message' do
      save_form_with(messages: { invalid_required: 'Required <script>alert(1)</script>' })

      expect(form.the_settings[:railscf_message]).to be_blank
      expect(flash[:error]).to include('response message')
    end

    it 'refuses script in the success message' do
      save_form_with(messages: { mail_sent_ok: 'Thanks <script>alert(1)</script>' })

      expect(form.the_settings[:railscf_message]).to be_blank
    end

    it 'accepts safe formatting in a response message' do
      save_form_with(messages: { mail_sent_ok: '<strong>Thanks!</strong>' })

      expect(form.the_settings[:railscf_message][:mail_sent_ok]).to eq('<strong>Thanks!</strong>')
    end

    # The recaptcha gem interpolates the site key into `data-sitekey="…"` without escaping it. The
    # rejection is asserted here rather than the render, because the gem skips emitting the tag
    # entirely in the test environment, so there is no rendered attribute to make an assertion about.
    it 'refuses a double quote in the recaptcha site key' do
      save_form_with(recaptcha_site_key: 'k" onmouseover="alert(1)')

      expect(form.the_settings[:recaptcha_site_key]).to be_blank
      expect(flash[:error]).to include('recaptcha_site_key')
    end

    it 'refuses a double quote in an option label, which reaches a value attribute' do
      save_form_with(options: { '0' => { label: 'x" onfocus="alert(1)', checked: 'false' } })

      expect(form.fields).to be_blank
    end

    # A rejected save must not half-apply. The name and slug are submitted alongside the fields, and
    # were previously persisted before validation ran.
    it 'leaves the record completely untouched when it refuses a save' do
      form.update!(name: 'Original name', slug: 'contact')
      save_form_with(previous_html: script)

      expect(form.reload.name).to eq('Original name')
      expect(form.the_settings[:railscf_mail]).to be_blank
    end

    it 'accepts ordinary content, and safe formatting, unchanged' do
      save_form_with(previous_html: '<h2>Get in touch</h2>', label: '<strong>Your name</strong>',
                     field_class: 'form-control large', default_value: 'Fish & Chips <today>')

      expect(form.the_settings[:railscf_mail][:previous_html]).to eq('<h2>Get in touch</h2>')
      expect(form.fields.first[:label]).to eq('<strong>Your name</strong>')
      expect(form.fields.first[:field_options][:field_class]).to eq('form-control large')
      expect(form.fields.first[:default_value]).to eq('Fish & Chips <today>')
    end

    it 'refuses a field_attributes value containing a double quote' do
      save_form_with(field_attributes: '{"data-x": "y\" onfocus=alert(1) z=\""}')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('field_attributes')
    end

    it 'refuses a field_attributes key that is not a valid attribute name' do
      save_form_with(field_attributes: '{"x onfocus=alert(1) y": "1"}')

      expect(form.fields).to be_blank
    end

    it 'accepts ordinary field_attributes' do
      save_form_with(field_attributes: '{"data-role": "input", "aria-label": "Name"}')

      expect(form.fields.first[:field_options][:field_attributes]).to include('data-role')
    end

    # The admin flash partial renders with `raw`, so the rejection message must never contain the
    # content it just rejected — otherwise refusing an injection becomes a way to perform one.
    # Each offending value is exercised on its own. Because the check is fail-fast, a form with two
    # problems only ever reports the first, so a single fixture would leave the later branches
    # unexercised and the assertion would pass for the wrong reason.
    {
      'wrapper markup' => { previous_html: '<img src=x onerror=alert(1)>' },
      'field label' => { label: '<script>alert(1)</script>' },
      'field description' => { description: '<script>alert(1)</script>' },
      'field template' => { template: '<div onload="alert(1)">[ci]</div>' },
      'option label' => { options: { '0' => { label: '<script>alert(1)</script>', checked: 'false' } } },
      'submit button label' => { name_button: '<script>alert(1)</script>' },
      'response message' => { messages: { invalid_required: '<script>alert(1)</script>' } },
      'paragraph default value' => { field_type: 'paragraph',
                                     default_value: '</textarea><script>alert(1)</script>' },
      'field_attributes event handler' => { field_attributes: '{"onload": "alert(1)"}' }
    }.each do |position, attrs|
      it "does not echo rejected #{position} back into the flash" do
        save_form_with(**attrs)

        expect(flash[:error]).not_to include('alert(1)')
        expect(flash[:error]).not_to include('<script')
        expect(flash[:error]).not_to include('onerror')
        expect(flash[:error]).not_to include('onload')
      end
    end

    it 'refuses a double quote in a field label, which reaches a name attribute' do
      save_form_with(label: 'Your "name"')

      expect(form.fields).to be_blank
    end
  end

  # Structural values are not authored content — the form builder generates them — so they are held
  # to an allowlist for everyone, including an author who may write raw HTML. A field typed
  # `text" onfocus="x` is a corrupt record, not a capability.
  context 'when the author is anyone at all, including an administrator' do
    let(:user) { create(:user, role: 'admin', site: current_site) }

    before { sign_in_as(user, site: current_site) }

    it 'refuses a cid that is not a plain identifier' do
      save_form_with(cid: 'c1" onfocus="alert(1)')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('cid')
    end

    it 'refuses a field type outside the known set' do
      save_form_with(field_type: 'text" onfocus="alert(1)')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('field type')
    end

    it 'refuses a non-numeric maxlength' do
      save_form_with(maxlength: '10" onfocus="alert(1)')

      expect(form.fields).to be_blank
      expect(flash[:error]).to include('maxlength')
    end

    it 'accepts the values the form builder actually produces' do
      save_form_with(cid: 'c17', field_type: 'paragraph', maxlength: '500')

      expect(form.fields.first[:cid]).to eq('c17')
      expect(form.fields.first[:field_type]).to eq('paragraph')
    end
  end

  context 'when the author holds the unfiltered-HTML grant' do
    let(:user) { role_with({ 'plugins' => 1, 'contact_form_unfiltered_html' => 1 }, 'forms-editor') }

    before { sign_in_as(user, site: current_site) }

    it 'stores script in the wrapper markup exactly as written' do
      save_form_with(previous_html: script)

      expect(form.the_settings[:railscf_mail][:previous_html]).to eq(script)
    end

    it 'stores an event handler in a field template exactly as written' do
      save_form_with(template: '<div onload="alert(1)">[ci]</div>')

      expect(form.fields.first[:field_options][:template]).to eq('<div onload="alert(1)">[ci]</div>')
    end

    it 'stores a double quote in a field class exactly as written' do
      save_form_with(field_class: 'form-control" onfocus="alert(1)')

      expect(form.fields.first[:field_options][:field_class]).to eq('form-control" onfocus="alert(1)')
    end

    # The counterweight to each rule added for an untrusted author: none of them constrains someone
    # holding the grant, which is the whole point of having a grant.
    it 'stores an event-handler attribute in field_attributes exactly as written' do
      save_form_with(field_attributes: '{"onfocus": "track()"}')

      expect(form.fields.first[:field_options][:field_attributes]).to eq('{"onfocus": "track()"}')
    end

    it 'stores a paragraph default value that closes the textarea exactly as written' do
      save_form_with(field_type: 'paragraph', default_value: '</textarea><script>track()</script>')

      expect(form.fields.first[:default_value]).to eq('</textarea><script>track()</script>')
    end

    it 'stores script in a response message exactly as written' do
      save_form_with(messages: { mail_sent_ok: 'Thanks<script>track()</script>' })

      expect(form.the_settings[:railscf_message][:mail_sent_ok]).to eq('Thanks<script>track()</script>')
    end
  end

  context 'when an administrator saves' do
    let(:user) { create(:user, role: 'admin', site: current_site) }

    it 'stores script unchanged, via can :manage, :all' do
      sign_in_as(user, site: current_site)
      save_form_with(previous_html: script)

      expect(form.the_settings[:railscf_mail][:previous_html]).to eq(script)
    end
  end

  context 'when the caller holds no plugin-management permission' do
    let(:user) { role_with({}, 'no-perms') }

    it 'never reaches the update at all' do
      sign_in_as(user, site: current_site)
      save_form_with

      expect(response).to have_http_status(:redirect)
      expect(form.the_settings[:railscf_mail]).to be_blank
    end
  end

  describe 'the trust predicate itself' do
    let(:controller) { Plugins::CamaContactForm::AdminFormsController.new }

    after do
      CurrentRequest.user = nil
      CurrentRequest.site = nil
    end

    it 'fails closed when there is no user context' do
      CurrentRequest.user = nil
      CurrentRequest.site = current_site

      expect(controller.send(:trusted_for_unfiltered_html?)).to be false
    end

    it 'fails closed when there is no site context' do
      CurrentRequest.user = create(:user, role: 'admin', site: current_site)
      CurrentRequest.site = nil

      expect(controller.send(:trusted_for_unfiltered_html?)).to be false
    end
  end
end
