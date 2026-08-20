# frozen_string_literal: true

require 'rails_helper'

# Reproduces the output-escaping defect in the bundled cama_contact_form plugin.
#
# `Plugins::CamaContactForm::MainHelper#cama_form_element_bootstrap_object` assembles form markup by
# raw string interpolation with no escaping, and `forms_shorcode.html.erb` emits the result through
# `raw`. Two trust levels reach those sinks, and the admin panel is same-origin with the frontend, so
# script landing here runs with an administrator's session.
RSpec.describe 'Security: contact form output escaping', type: :request do
  let!(:site) { CamaleonCms::Site.first.decorate }

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

  # Fill every required field so the submission actually completes: that is the branch that stores a
  # response row and sends the notification e-mail.
  def submit_succeeding(form, fields)
    post '/plugins/cama_contact_form/save_form', params: { id: form.id, fields: fields }
  end

  def stored_answer(form, cid)
    JSON.parse(form.responses.last.settings)['fields'][cid.to_s]
  end

  # The notification e-mail is the second sink a visitor's value reaches, and it is a markup sink:
  # `cama_replace_codes` splices the value into the author's body and the mailer renders the result
  # with `raw`. The redisplay rules -- a quote, or `</textarea` -- say nothing about that context.
  describe 'values a visitor sends into the notification e-mail' do
    before { ActionMailer::Base.deliveries.clear }

    it 'refuses a value carrying an event handler, storing nothing and sending nothing' do
      form = build_form(fields: [text_field], settings: {
                          'railscf_mail' => { 'to' => 'owner@example.com', 'subject' => 's',
                                              'body' => 'New message: [c1]' }
                        })
      publish_form_on_sample_post

      expect do
        submit_succeeding(form, { c1: '<img src=x onerror=alert(document.domain)>' })
      end.not_to(change { ActionMailer::Base.deliveries.count })

      expect(form.responses.count).to eq(0)
    end

    it 'refuses a script element in a value the e-mail body interpolates' do
      form = build_form(fields: [text_field], settings: {
                          'railscf_mail' => { 'to' => 'owner@example.com', 'subject' => 's',
                                              'body' => 'New message: [c1]' }
                        })
      publish_form_on_sample_post

      submit_succeeding(form, { c1: '<script>alert(1)</script>' })

      expect(form.responses.count).to eq(0)
    end

    # The rule is narrow on purpose. Running a sanitizer here would refuse ordinary prose, and being
    # told "your message contains characters that are not allowed" for writing `<today>` is both
    # wrong and infuriating.
    it 'accepts ordinary prose containing angle brackets and delivers it' do
      form = build_form(fields: [text_field], settings: {
                          'railscf_mail' => { 'to' => 'owner@example.com', 'subject' => 's',
                                              'body' => 'New message: [c1]' }
                        })
      publish_form_on_sample_post

      expect do
        submit_succeeding(form, { c1: 'Fish & Chips <today> please' })
      end.to change { form.responses.count }.by(1)

      # Stored exactly as written, which is what `[c1]` then splices into the mail body.
      expect(stored_answer(form, :c1)).to eq('Fish & Chips <today> please')
    end
  end

  # A submission is rejected, not escaped, on the same principle as an author's content: what gets
  # redisplayed then equals what was submitted, so rendering it verbatim adds nothing. The redisplay
  # is the only reason a submission reaches the page at all, so a submission carrying anything malign
  # is refused whole and echoed back not at all — otherwise the rejection becomes the injection.
  describe 'values submitted by an unauthenticated visitor' do
    it 'refuses a value that would introduce an event-handler attribute, and echoes nothing back' do
      form = build_form(fields: [text_field, text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '" autofocus onfocus="alert(1)', c2: '' })
      input = doc.at_css('input[name="fields[c1]"]')

      expect(input.attributes.keys).not_to include('onfocus', 'autofocus')
      expect(input['value']).to be_blank
    end

    it 'refuses a value that would close the textarea and open a script' do
      form = build_form(fields: [
                          { label: 'Msg', field_type: 'paragraph', cid: 'c1', required: 'true', field_options: {} },
                          text_field(cid: 'c2')
                        ])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '</textarea><script>alert(1)</script>', c2: '' })

      expect(doc.css('script').map(&:text).join).not_to include('alert(1)')
      expect(doc.at_css('textarea[name="fields[c1]"]').text).to be_blank
    end

    it 'refuses the payload in every field type that echoes it' do
      fields = %w[text website email].each_with_index.map do |type, i|
        { label: type, field_type: type, cid: "c#{i + 1}", required: 'true', field_options: {} }
      end
      form = build_form(fields: fields + [text_field(cid: 'c9', label: 'Blank')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '" onfocus="alert(1)', c2: '" onfocus="alert(1)',
                                   c3: '" onfocus="alert(1)', c9: '' })

      %w[c1 c2 c3].each do |cid|
        input = doc.at_css(%(input[name="fields[#{cid}]"]))
        expect(input.attributes.keys).not_to include('onfocus'), "#{cid} admitted an onfocus attribute"
        expect(input['value']).to be_blank
      end
    end

    it 'echoes back nothing at all when any one value is refused' do
      form = build_form(fields: [text_field(label: 'Your name'),
                                 text_field(cid: 'c2', label: 'Company'),
                                 text_field(cid: 'c3', label: 'Blank')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '" onfocus="alert(1)', c2: 'Acme Ltd', c3: '' })

      # the innocuous sibling is dropped too: the form is refused whole rather than half-echoed
      expect(doc.at_css('input[name="fields[c1]"]')['value']).to be_blank
      expect(doc.at_css('input[name="fields[c2]"]')['value']).to be_blank
    end

    # The case the early bail exists for. Every other visitor example leaves a required field blank,
    # so validation would have failed regardless — this one is otherwise perfectly valid, so it is
    # refused only because the content is malign. Without the bail it would be stored and mailed.
    it 'refuses an otherwise-valid submission, storing no response and sending no mail' do
      form = build_form(fields: [text_field, text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      expect do
        submit_failing(form, { c1: '" onfocus="alert(1)', c2: 'a genuine message' })
      end.not_to(change { ActionMailer::Base.deliveries.count })

      expect(form.responses.count).to eq(0)
    end

    # The frontend flash is rendered with `raw` too, so the refusal quotes nothing back — it says
    # what to do without repeating what was submitted or naming a field with an authored label.
    it 'tells the visitor what to fix without echoing anything they submitted' do
      form = build_form(fields: [text_field(label: 'Your name'), text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '" onfocus="alert(1)<script>pwned()</script>', c2: '' })

      expect(doc.text).to include('characters that are not allowed')
      expect(doc.to_html).not_to include('onfocus="alert(1)')
      expect(doc.css('script').map(&:text).join).not_to include('pwned')
    end

    # A quote is ordinary prose, and a message is redisplayed as textarea content where it cannot
    # break anything — so it must not be refused.
    it 'accepts a quote in a paragraph and echoes it back' do
      form = build_form(fields: [
                          { label: 'Msg', field_type: 'paragraph', cid: 'c1', required: 'true', field_options: {} },
                          text_field(cid: 'c2')
                        ])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: 'He said "hello" & left', c2: '' })

      expect(doc.at_css('textarea[name="fields[c1]"]').text).to eq('He said "hello" & left')
    end

    # `||`, not `.presence`: a visitor who clears a prefilled field and resubmits meant to clear it,
    # so the default must not reappear.
    it 'keeps a deliberately cleared field empty rather than restoring its default' do
      form = build_form(fields: [text_field(default_value: 'Prefilled'), text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '', c2: '' })

      expect(doc.at_css('input[name="fields[c1]"]')['value']).to be_blank
    end

    it 'accepts ordinary text and echoes it back unchanged' do
      form = build_form(fields: [text_field, text_field(cid: 'c2', label: 'Msg')])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: 'Fish & Chips <today>', c2: '' })

      expect(doc.at_css('input[name="fields[c1]"]')['value']).to eq('Fish & Chips <today>')
    end
  end

  # The counterweight to everything above. Every authored value renders verbatim, so an author with
  # the unfiltered-HTML grant can put markup — or script — anywhere in the form and have guests
  # receive it as written. What keeps an untrusted author's content out is the admin controller
  # refusing to store it (contact_form_content_rejection_spec.rb), not escaping here.
  describe 'authored values render verbatim' do
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

    it 'emits a custom field template as markup, with its label substituted in' do
      build_form(fields: [text_field(label: 'Your name',
                                     field_options: {
                                       template: "<div class='wrapper'><label>[label ci]</label>[ci]</div>"
                                     })])
      publish_form_on_sample_post

      get '/sample-post'
      doc = Nokogiri::HTML5.parse(response.body)

      expect(doc.at_css('div.wrapper')).to be_present
      expect(doc.at_css('div.wrapper label').text).to eq('Your name')
      expect(doc.at_css('div.wrapper input[name="fields[c1]"]')).to be_present
    end

    it 'renders formatting markup in a field label rather than escaping it' do
      build_form(fields: [text_field(label: '<strong>Your name</strong> <em>(required)</em>')])
      publish_form_on_sample_post

      get '/sample-post'
      doc = Nokogiri::HTML5.parse(response.body)

      expect(doc.at_css('label strong')&.text).to eq('Your name')
      expect(doc.at_css('label em')&.text).to eq('(required)')
    end

    it 'renders a link in a field description rather than escaping it' do
      build_form(fields: [text_field(field_options: { description: 'See our <a href="/privacy">privacy policy</a>' })])
      publish_form_on_sample_post

      get '/sample-post'

      expect(Nokogiri::HTML5.parse(response.body).at_css('a[href="/privacy"]')&.text).to eq('privacy policy')
    end

    # Radio and checkbox option labels render inside a <label>, where markup is permitted. A dropdown's
    # options are not covered by this: <option> is text-only per the HTML spec, so a browser drops any
    # element inside it no matter what the server emits.
    # The capability the unfiltered-HTML permission exists to grant. A guest — unauthenticated, no
    # session — receives the script exactly as the trusted author wrote it.
    it 'delivers a script an author stored in the wrapper markup to an anonymous visitor' do
      build_form(fields: [text_field],
                 settings: { 'railscf_mail' => {
                   'to' => 'owner@example.com', 'subject' => 's', 'body' => 'b',
                   'previous_html' => '<script>window.tracked = true;</script>'
                 } })
      publish_form_on_sample_post

      get '/sample-post'

      expect(Nokogiri::HTML5.parse(response.body).css('script').map(&:text).join)
        .to include('window.tracked = true;')
    end

    it 'delivers an event handler an author stored in a field class to an anonymous visitor' do
      build_form(fields: [text_field(field_options: { field_class: 'form-control" onfocus="track()' })])
      publish_form_on_sample_post

      get '/sample-post'
      input = Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')

      # the template appends the field-type class after the interpolation, so the handler picks up
      # trailing whitespace on the way out
      expect(input['onfocus']&.strip).to eq('track()')
    end

    it 'delivers an event handler an author stored in field_attributes to an anonymous visitor' do
      build_form(fields: [text_field(field_options: { field_attributes: '{"onfocus": "track()"}' })])
      publish_form_on_sample_post

      get '/sample-post'

      expect(Nokogiri::HTML5.parse(response.body).at_css('input[name="fields[c1]"]')['onfocus']).to eq('track()')
    end

    # Would have caught a regression that replaced the control type with the field type: a
    # `checkboxes` field renders type="checkbox", and a `dropdown` renders a <select>.
    it 'renders each field type with the control type it actually needs' do
      build_form(fields: [
                   { label: 'Pick', field_type: 'checkboxes', cid: 'c1', required: 'false',
                     field_options: { options: [{ label: 'One', checked: false }] } },
                   { label: 'Choose', field_type: 'dropdown', cid: 'c2', required: 'false',
                     field_options: { options: [{ label: 'Two', checked: false }] } }
                 ])
      publish_form_on_sample_post

      get '/sample-post'
      doc = Nokogiri::HTML5.parse(response.body)

      expect(doc.at_css('input[name="fields[c1][]"]')['type']).to eq('checkbox')
      expect(doc.at_css('select[name="fields[c2]"]')).to be_present
      expect(doc.at_css('select[name="fields[c2]"] option')&.text&.strip).to eq('Two')
    end

    it 'renders markup in a radio option label rather than escaping it' do
      build_form(fields: [{ label: 'Pick', field_type: 'radio', cid: 'c1', required: 'true',
                            field_options: { options: [{ label: '<b>Bold option</b>', checked: false }] } }])
      publish_form_on_sample_post

      get '/sample-post'

      expect(Nokogiri::HTML5.parse(response.body).at_css('label b')&.text).to eq('Bold option')
    end

    # These three are what the gate refuses from an untrusted author, proved here to be genuinely
    # dangerous rather than theoretically so: each reaches an anonymous guest as live script. They
    # are written straight into the record, which is what a trusted author's save produces.
    it 'delivers a paragraph default value that closes its own textarea' do
      build_form(fields: [{ label: 'Msg', field_type: 'paragraph', cid: 'c1', required: 'false',
                            default_value: '</textarea><script>window.tracked = true;</script>',
                            field_options: {} }])
      publish_form_on_sample_post

      get '/sample-post'

      expect(Nokogiri::HTML5.parse(response.body).css('script').map(&:text).join)
        .to include('window.tracked = true;')
    end

    # `[descr ci]` is substituted wherever the template puts it, and the template is authored, so a
    # description is not confined to element content.
    it 'delivers a description the template placed inside an attribute' do
      build_form(fields: [text_field(field_options: {
                                       template: '<div title="[descr ci]">[ci]</div>',
                                       description: 'x" onmouseover="track()'
                                     })])
      publish_form_on_sample_post

      get '/sample-post'

      expect(Nokogiri::HTML5.parse(response.body).at_css('div[title]')['onmouseover']).to eq('track()')
    end

    # The three placeholders used to be substituted in sequence -- `[ci]` first, then `[descr ci]`,
    # then `[label ci]` -- each pass scanning the output of the one before it. So a visitor typing
    # the literal `[label ci]` into a message had the author's label spliced into the middle of the
    # textarea that was echoing their own words back, and a label of `</textarea>…` broke out of it.
    # One pass, so no replacement is ever scanned for the next placeholder.
    it 'does not substitute a placeholder a visitor typed into their own message' do
      form = build_form(fields: [
                          { label: 'Msg', field_type: 'paragraph', cid: 'c1', required: 'true',
                            field_options: {} },
                          text_field(cid: 'c2')
                        ])
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: 'send me [label ci] please', c2: '' })

      expect(doc.at_css('textarea[name="fields[c1]"]').text).to eq('send me [label ci] please')
    end

    # railscf_message values are joined into flash[:contact_form], which the frontend flash partial
    # renders with `raw`.
    it 'delivers a response message to a visitor whose submission failed validation' do
      form = build_form(fields: [text_field],
                        settings: { 'railscf_message' => {
                          'invalid_required' => 'Required <script>window.tracked = true;</script>'
                        } })
      publish_form_on_sample_post

      doc = submit_failing(form, { c1: '' })

      expect(doc.css('script').map(&:text).join).to include('window.tracked = true;')
    end
  end
end
