# frozen_string_literal: true

# When a draft buffer is edited, its stored `draft_status` is interpolated into the Recover button's
# inline `onclick` JavaScript. The save now refuses a request-submitted `draft_status`, but a value
# already stored (legacy data, or a server-side write) must not break out of the JS string, so it is
# escaped for the JavaScript context.
RSpec.describe 'Security: recover button draft_status escaping', type: :request do
  include_context 'with the post editor'

  let(:payload) { "x');alert(document.domain);//" }

  it 'escapes a stored draft_status in the Recover button onclick' do
    parent = create(:post, post_type: post_type, owner: admin, status: 'published')
    buffer = create(:post, post_type: post_type, owner: admin, status: 'draft_child', parent: parent)
    buffer.set_option('draft_status', payload)
    sign_in_as(admin, site: current_site)

    get "/admin/post_type/#{post_type.id}/posts/#{buffer.id}/edit"

    onclick = Nokogiri::HTML5.parse(response.body).at_css('input[onclick*="post_status"]')['onclick']
    escaped = ActionController::Base.helpers.escape_javascript(payload)
    # The payload's quote is now backslash-escaped (`\'`), so it cannot close the val('...') string.
    expect(onclick).to eq("$('#post_status').val('#{escaped}')")
  end
end
