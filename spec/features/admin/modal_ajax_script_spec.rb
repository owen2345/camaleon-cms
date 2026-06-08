# frozen_string_literal: true

require 'rails_helper'

describe 'Modal AJAX script execution (jQuery 3 compat)', :js do
  # jQuery 3's .html() does not execute <script> tags on detached DOM elements.
  # The fix appends the modal to document.body before setting HTML content,
  # ensuring inline scripts (like cama_init_media) run correctly in AJAX modals.
  #
  # See: app/assets/javascripts/camaleon_cms/admin/_modal.js (modal.appendTo("body"))

  init_site

  it 'executes inline scripts in AJAX modal content' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/media"

    # Verify the media gallery was initialized by cama_init_media()
    # (called via inline <script> in media/index.html.erb)
    events_bound = page.evaluate_script(<<~JS)
      (function() {
        var gallery = document.getElementById('cama_media_gallery');
        if (!gallery) return { error: 'gallery not found' };
        var events = $._data(gallery, 'events');
        return {
          hasClick: events && !!events.click,
          eventTypes: events ? Object.keys(events) : []
        };
      })()
    JS

    expect(events_bound['error']).to be_nil, 'Media gallery not found in DOM'
    expect(events_bound['hasClick']).to be(true),
           "Expected click events on #cama_media_gallery but got: #{events_bound['eventTypes']}"
  end
end
