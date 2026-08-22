# frozen_string_literal: true

require 'rails_helper'

# Security (scan-and-reject policy, PR #1169 review finding #1 -- stored XSS via tag names):
# the tag editor and the tagsInput plugin render autocomplete suggestions (post_tags#list ->
# pluck('name')) through Awesomplete's default innerHTML item renderer, whereas the jQuery UI
# autocomplete they replaced rendered labels with .text(). Tag names were stored verbatim with no
# gate, so a tag named `<img src=x onerror=...>` planted by a low-trust author (Contributor: `edit`
# on the post type, which is the create_post ability) executes in the admin post form of every
# Editor/Admin who types a matching character. The remedy is a save-time refusal of a dangerous tag
# name (never a render-time transform), sharing the content gate's trust model: admins and roles
# holding post_content_unfiltered_html store anything; the unfiltered_content! opt-out covers
# server-side pipelines.
RSpec.describe CamaleonCms::Post, type: :model do
  describe 'tag rejection' do
    let(:site) { create(:site) }
    let(:post_type) do
      pt = create(:post_type, site: site)
      pt.set_option('has_tags', true) # memoized `options` is stale on this instance; reload a fresh one
      CamaleonCms::PostType.find(pt.id)
    end
    let(:admin) { create(:user, role: 'admin', site: site) }
    let(:contributor) { create(:user, role: 'contributor', site: site) }
    let(:xss_tag) { '<img src=x onerror=alert(1)>evil' }

    def assign_current_user(user)
      CurrentRequest.user = user
      CurrentRequest.site = site
    end

    def build_post(tags, owner: nil, content: '<p>ok</p>')
      build(:post, post_type: post_type, owner: owner, content: content).tap { |p| p.data_tags = tags }
    end

    after do
      CurrentRequest.user = nil
      CurrentRequest.site = nil
    end

    context 'when the author lacks post_content_unfiltered_html' do
      before { assign_current_user(contributor) }

      it 'refuses a tag name carrying an event handler and stores no tag' do
        post = build_post("#{xss_tag}, ruby", owner: contributor)

        expect(post.save).to be false
        expect(post.errors[:base].join).to include('not allowed for your role')
        expect(post_type.post_tags.pluck(:name).join).not_to include('onerror')
      end

      it 'refuses a script element in a tag name' do
        expect(build_post('<script>alert(1)</script>', owner: contributor)).not_to be_valid
      end

      it 'refuses an SVG event handler in a tag name' do
        expect(build_post('<svg onload=alert(1)>', owner: contributor)).not_to be_valid
      end

      it 'stores benign multi-word tags verbatim' do
        post = build_post('New York, C++, tag three', owner: contributor)

        expect(post.save).to be true
        expect(post.reload.post_tags.pluck(:name)).to contain_exactly('New York', 'C++', 'tag three')
      end

      it 'accepts a post that sets no tags (data_tags nil)' do
        post = build(:post, post_type: post_type, owner: contributor, content: '<p>ok</p>')

        expect(post.data_tags).to be_nil
        expect(post.save).to be true
      end
    end

    context 'when the author holds post_content_unfiltered_html' do
      it 'stores a markup tag name verbatim for an admin' do
        assign_current_user(admin)
        post = build_post(xss_tag, owner: admin)

        expect(post.save).to be true
        expect(post.reload.post_tags.pluck(:name)).to include(xss_tag)
      end

      it 'trusts the explicit server-side unfiltered_content! opt-out' do
        assign_current_user(contributor)
        post = build_post(xss_tag, owner: contributor).unfiltered_content!

        expect(post.save).to be true
      end
    end

    context 'when user context is absent (fail closed)' do
      it 'refuses a dangerous tag name with no user set' do
        CurrentRequest.user = nil
        CurrentRequest.site = nil

        expect(build_post(xss_tag, owner: contributor)).not_to be_valid
      end
    end
  end
end
