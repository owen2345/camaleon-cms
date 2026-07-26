# frozen_string_literal: true

require 'rails_helper'

# The contact form's wrapper markup and per-field templates are rendered unescaped by design, so
# escaping them would break the feature. They are sanitized when the form is saved instead, unless
# the saving user holds `:manage, :contact_form_unfiltered_html`.
#
# Without this, any role holding `:manage, :plugins` — the only gate on the plugin's admin controller,
# and not necessarily an administrator — could store script that runs in an administrator's session.
RSpec.describe 'Security: contact form settings sanitization', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:form) { current_site.contact_forms.create!(name: 'Contact', slug: 'contact') }
  let(:payload) { '<p>keep</p><script>alert(1)</script>' }

  before do
    current_site.plugins.where(slug: 'cama_contact_form').first_or_create(set_meta: { status: 'active' })
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def save_form_with(previous_html: payload, template: payload)
    patch "/admin/plugins/cama_contact_form/admin_forms/#{form.id}", params: {
      plugins_cama_contact_form_cama_contact_form: { name: 'Contact', slug: 'contact' },
      railscf_mail: { to: 'a@b.c', subject: 's', body: 'b', previous_html: previous_html, after_html: previous_html },
      railscf_message: {},
      railscf_form_button: { name_button: 'Send' },
      fields: { c1: { label: 'Name', field_type: 'text', cid: 'c1', required: 'false',
                      field_options: { template: template } } }
    }
    form.reload
  end

  def role_with(manager_meta, slug)
    role = current_site.user_roles.create!(name: slug, slug: slug)
    role.set_meta("_manager_#{current_site.id}", manager_meta)
    create(:user, role: slug, site: current_site)
  end

  context 'when the saving user holds :manage, :plugins but not the unfiltered-HTML grant' do
    let(:user) { role_with({ 'plugins' => 1 }, 'plugins-manager') }

    it 'strips script from the markup wrapping the form' do
      sign_in_as(user, site: current_site)
      save_form_with

      expect(form.the_settings[:railscf_mail][:previous_html]).not_to include('<script>')
      expect(form.the_settings[:railscf_mail][:previous_html]).to include('<p>keep</p>')
    end

    it 'strips script from the after_html wrapper too' do
      sign_in_as(user, site: current_site)
      save_form_with

      expect(form.the_settings[:railscf_mail][:after_html]).not_to include('<script>')
    end

    it 'strips an event handler from a field template while preserving its placeholder' do
      sign_in_as(user, site: current_site)
      save_form_with(template: '<div onload="alert(1)">[ci]</div>')

      stored = form.fields.first[:field_options][:template]
      expect(stored).not_to include('onload')
      expect(stored).to include('[ci]')
    end
  end

  context 'when the saving user holds the unfiltered-HTML grant' do
    let(:user) { role_with({ 'plugins' => 1, 'contact_form_unfiltered_html' => 1 }, 'forms-editor') }

    it 'stores the markup unchanged' do
      sign_in_as(user, site: current_site)
      save_form_with

      expect(form.the_settings[:railscf_mail][:previous_html]).to include('<script>alert(1)</script>')
    end
  end

  context 'when an administrator saves' do
    let(:user) { create(:user, role: 'admin', site: current_site) }

    it 'stores the markup unchanged, via can :manage, :all' do
      sign_in_as(user, site: current_site)
      save_form_with

      expect(form.the_settings[:railscf_mail][:previous_html]).to include('<script>alert(1)</script>')
    end
  end

  context 'when the caller holds no plugin-management permission' do
    let(:user) { role_with({}, 'no-perms') }

    it 'never reaches the update at all' do
      sign_in_as(user, site: current_site)
      save_form_with

      expect(response).to have_http_status(:redirect)
      # the model seeds settings to "{}" on create, so assert the update's payload never landed
      expect(form.the_settings[:railscf_mail]).to be_blank
    end
  end

  # The `CurrentRequest.user.blank? || site.blank?` guard in `trusted_for_unfiltered_html?` is not
  # reachable through this endpoint — `authorize! :manage, :plugins` rejects a contextless caller
  # first, as the example above pins. It is defence in depth for callers that bypass the controller
  # entirely (console, rake tasks, background jobs), matching `Post#trusted_for_unfiltered_html?`,
  # and is covered at that level rather than here.
  describe 'the trust predicate itself' do
    let(:controller) { Plugins::CamaContactForm::AdminFormsController.new }

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
