# frozen_string_literal: true

require 'rails_helper'

# Reproduces the output-escaping defect in the bundled cama_contact_form plugin.
#
# `Plugins::CamaContactForm::MainHelper#cama_form_element_bootstrap_object` assembles form markup by
# raw string interpolation with no escaping, and `forms_shorcode.html.erb` emits the result through
# `raw`. Two trust levels reach those sinks, and the admin panel is same-origin with the frontend, so
# script landing here runs with an administrator's session.
RSpec.describe 'Security: contact form output escaping', type: :request do
  let!(:site) { create(:site).decorate }

  # `required` is stored as the string "true" by the form editor (hidden_field_tag + check_box_tag),
  # not as a JSON boolean — the plugin calls `.to_bool`, which Camaleon defines only on String.
  def build_form(fields:, settings: {})
    site.contact_forms.create!(
      name: 'Contact', slug: 'contact',
      value: { fields: fields }.to_json,
      settings: {
        'railscf_mail' => { 'to' => 'owner@example.com', 'subject' => 'subject', 'body' => 'body' },
        'railscf_message' => {},
        'railscf_form_button' => { 'name_button' => 'Send' }
      }.merge(settings).to_json
    )
  end

  def text_field(cid: 'c1', **overrides)
    { label: 'Name', field_type: 'text', cid: cid, required: 'true', field_options: {} }.merge(overrides)
  end

  def publish_form_on_sample_post
    site.the_post('sample-post').update!(content: "[forms slug='contact']")
  end

  # Submit with a required field left blank so validation fails; that is the branch which stashes the
  # raw submission into flash[:values] for redisplay.
  def submit_failing(form, fields)
    post '/plugins/cama_contact_form/save_form', params: { id: form.id, fields: fields }
    follow_redirect!
    Nokogiri::HTML5.parse(response.body)
  end

  describe 'values echoed back to an unauthenticated visitor' do
    it 'does not let a text field value introduce an event-handler attribute' do
      form = build_form(fields: [text_field, text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '" autofocus onfocus="alert(1)', c2: '' })
      input = doc.at_css('input[name="fields[c1]"]')

      expect(input).to be_present
      expect(input.attributes.keys).not_to include('onfocus', 'autofocus')
      expect(input['value']).to eq('" autofocus onfocus="alert(1)')
    end

    it 'does not let a paragraph value close the textarea and open a script' do
      form = build_form(fields: [
                          { label: 'Msg', field_type: 'paragraph', cid: 'c1', required: 'true', field_options: {} },
                          text_field(cid: 'c2')
                        ])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '</textarea><script>alert(1)</script>', c2: '' })

      expect(doc.css('script').map(&:text).join).not_to include('alert(1)')
      expect(doc.at_css('textarea[name="fields[c1]"]').text).to eq('</textarea><script>alert(1)</script>')
    end

    it 'escapes the payload in every field type that echoes it' do
      fields = %w[text website email].each_with_index.map do |type, i|
        { label: type, field_type: type, cid: "c#{i + 1}", required: 'true', field_options: {} }
      end
      form = build_form(fields: fields + [text_field(cid: 'c9', label: 'Blank')])
      publish_form_on_sample_post

      payload = '" onfocus="alert(1)'
      doc = submit_failing(form, { c1: payload, c2: payload, c3: payload, c9: '' })

      %w[c1 c2 c3].each do |cid|
        input = doc.at_css(%(input[name="fields[#{cid}]"]))
        expect(input.attributes.keys).not_to include('onfocus'), "#{cid} admitted an onfocus attribute"
        expect(input['value']).to eq(payload)
      end
    end

    it 'shows legitimate input back as text rather than entities' do
      form = build_form(fields: [text_field, text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: 'Fish & Chips <today>', c2: '' })

      expect(doc.at_css('input[name="fields[c1]"]')['value']).to eq('Fish & Chips <today>')
    end
  end

  # The counterweight to everything above: three stored values exist to carry site markup and must
  # keep rendering unescaped. Escaping them would be a functional regression, not a fix — they are
  # governed by save-time sanitization instead.
  describe 'markup-by-contract values still render as markup' do
    it 'emits the wrapper markup around the form unescaped' do
      build_form(fields: [text_field],
                 settings: { 'railscf_mail' => {
                   'to' => 'owner@example.com', 'subject' => 's', 'body' => 'b',
                   'previous_html' => '<h2 class="intro">Get in touch</h2>',
                   'after_html' => '<p><a href="/privacy">Privacy</a></p>'
                 } })
      publish_form_on_sample_post

      get '/sample-post'
      doc = Nokogiri::HTML5.parse(response.body)

      expect(doc.at_css('h2.intro')&.text).to eq('Get in touch')
      expect(doc.at_css('a[href="/privacy"]')&.text).to eq('Privacy')
    end

    it 'emits a custom field template as markup while escaping the label it carries' do
      build_form(fields: [text_field(label: 'Your <name>',
                                     field_options: {
                                       template: "<div class='wrapper'><label>[label ci]</label>[ci]</div>"
                                     })])
      publish_form_on_sample_post

      get '/sample-post'
      doc = Nokogiri::HTML5.parse(response.body)

      expect(doc.at_css('div.wrapper')).to be_present
      expect(doc.at_css('div.wrapper label').text).to eq('Your <name>')
      expect(doc.at_css('div.wrapper input[name="fields[c1]"]')).to be_present
    end
  end

  describe 'values stored in the form definition' do
    # Reachable by any role holding `:manage, :plugins`, which PluginsAdminController is the only gate
    # on. That is not necessarily an administrator, so this is a privilege boundary crossing.
    it 'does not let a field label inject a script element' do
      build_form(fields: [text_field(label: '<script>alert(1)</script>')])
      publish_form_on_sample_post

      get '/sample-post'
      doc = Nokogiri::HTML5.parse(response.body)

      expect(doc.css('script').map(&:text).join).not_to include('alert(1)')
      expect(doc.text).to include('<script>alert(1)</script>')
    end

    it 'does not let a field class introduce an event-handler attribute' do
      build_form(fields: [text_field(field_options: { field_class: 'form-control" onmouseover="alert(1)' })])
      publish_form_on_sample_post

      get '/sample-post'
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      expect(input.attributes.keys).not_to include('onmouseover')
    end

    it 'does not let a select option label introduce an event-handler attribute' do
      # The option value is passed through `.downcase.gsub(' ', '_')`, so a space-separated payload
      # would arrive as `_onfocus` and slip past a naive assertion while still injecting. Separate the
      # attributes with `/`, which HTML accepts and the gsub leaves alone.
      build_form(fields: [{ label: 'Pick', field_type: 'dropdown', cid: 'c1', required: 'true',
                            field_options: { options: [{ label: 'x"/onfocus="alert(1)', checked: false }] } }])
      publish_form_on_sample_post

      get '/sample-post'
      option = Nokogiri::HTML5.parse(response.body).at_css('select[name="fields[c1]"] option')

      expect(option).to be_present
      expect(option.attributes.keys).to all(be_in(%w[value selected]))
    end

    it 'does not let field_attributes inject a second attribute through the value' do
      build_form(fields: [text_field(field_options: { field_attributes: '{"data-x": "y\" onfocus=alert(1) z=\""}' })])
      publish_form_on_sample_post

      get '/sample-post'
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      expect(input.attributes.keys).not_to include('onfocus')
      expect(input['data-x']).to eq('y" onfocus=alert(1) z="')
    end

    # field_attributes is parsed as JSON, so its *keys* are attacker-controlled too. Escaping cannot
    # defend that position, so the attribute-name guard in Hash#to_attr_format drops the pair.
    it 'does not let a field_attributes key inject a second attribute' do
      build_form(fields: [text_field(field_options: { field_attributes: '{"x onfocus=alert(1) y": "1"}' })])
      publish_form_on_sample_post

      get '/sample-post'
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      expect(input.attributes.keys).not_to include('onfocus')
    end
  end
end
