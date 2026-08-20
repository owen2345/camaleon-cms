# frozen_string_literal: true

require 'rails_helper'

# Originally the reproduction for stored XSS in post content (a script stored in `content` emitted
# on the frontend). Under the scan-and-reject policy the protection lives at the storage gate: an
# untrusted save carrying the payload is refused outright, stored content always equals authored
# content, and `the_content` renders it verbatim with no render-time transform — the same contract
# as the templates' `raw post.the_content`.
describe CamaleonCms::Frontend::ContentSelectHelper do
  let(:site) { create(:site) }
  # the site install already creates a 'post' post type; a second one with the
  # same slug under the same site is (correctly) rejected as a duplicate
  let(:post_type) { site.post_types.find_by!(slug: 'post') }
  let(:xss_payload) { '<script>alert("xss")</script>' }

  before do
    # a second site exists (the suite-wide shared one), so pin this spec's own
    # site as current instead of relying on single-site fallback resolution
    store_current_site(site.decorate)
  end

  describe '#the_content' do
    it 'is unreachable with untrusted script content: the storage gate refuses the save' do
      expect do
        create(:post, post_type: post_type, title: 'Malicious Post', content: xss_payload, status: 'published')
      end.to raise_error(ActiveRecord::RecordInvalid, /not allowed for your role/)
    end

    it 'renders gate-passed stored content verbatim' do
      post = build(:post, post_type: post_type, title: 'Trusted Post', status: 'published',
                          content: '<p>hello</p><script>trustedWidget()</script>')
      post.unfiltered_content!
      post.save!
      CurrentRequest.frontend_object = post.decorate

      expect(the_content).to include('<script>trustedWidget()</script>')
    end
  end
end
