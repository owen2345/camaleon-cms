# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M7): media#upload no longer skips CSRF, so the multipart uploader (which
# posts outside jquery_ujs' ajax prefilter) must attach the token itself as an authenticity_token
# form field. The request spec proves the server rejects a token-less upload; this feature spec
# proves the client half by spying on FormData#append: the uploader must add authenticity_token to
# the multipart body. Reverting the customFileData token line makes this red.
RSpec.describe 'Media upload attaches the CSRF token (M7)', :js do
  init_site

  it 'adds authenticity_token to the multipart upload body' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/media"

    # Record every field the uploader appends to its FormData, without depending on server-side
    # forgery enforcement (already covered by the request spec).
    page.execute_script(<<~JS)
      window.__uploadFields = [];
      var append = FormData.prototype.append;
      FormData.prototype.append = function(name, value) {
        window.__uploadFields.push(name);
        return append.apply(this, arguments);
      };
    JS

    attach_file('file_upload[]', "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", make_visible: true)
    wait_for_ajax

    expect(page.evaluate_script('window.__uploadFields')).to include('authenticity_token')
  end
end
