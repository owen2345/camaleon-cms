# frozen_string_literal: true

require 'rails_helper'

# Security (scan-and-reject policy, 2026-08-13): post content an untrusted author is not permitted
# to write is refused with a validation error -- never sanitized or rewritten -- so stored content
# always equals authored content and the frontend renders it verbatim. Trusted savers (admins, or a
# role holding post_content_unfiltered_html for the post type) store anything; the explicit
# unfiltered_content! opt-out covers server-side pipelines. This supersedes the earlier
# sanitize-on-save remedy; the trust model and opt-out semantics are unchanged.
RSpec.describe CamaleonCms::Post, type: :model do
  describe 'content rejection' do
    let(:site) { create(:site) }
    let(:post_type) { create(:post_type, site: site) }
    let(:admin) { create(:user, role: 'admin', site: site) }
    let(:contributor) { create(:user, role: 'contributor', site: site) }
    let(:script_content) { '<p>Hello</p><script>alert(1)</script>' }

    def assign_current_user(user)
      CurrentRequest.user = user
      CurrentRequest.site = site
    end

    def build_post(content, owner: nil)
      build(:post, post_type: post_type, owner: owner, content: content)
    end

    after do
      CurrentRequest.user = nil
      CurrentRequest.site = nil
    end

    context 'when the author lacks post_content_unfiltered_html' do
      before { assign_current_user(contributor) }

      it 'refuses a script element and stores nothing' do
        post = build_post(script_content, owner: contributor)

        expect(post).not_to be_valid
        expect(post.errors[:content].join).to include('not allowed for your role')
      end

      it 'refuses SVG event handlers' do
        post = build_post('<svg xmlns="http://www.w3.org/2000/svg"><animate onbegin="alert(1)"/></svg>',
                          owner: contributor)

        expect(post).not_to be_valid
      end

      it 'refuses a javascript: URL in a link' do
        post = build_post('<a href="javascript:alert(1)">click</a>', owner: contributor)

        expect(post).not_to be_valid
      end

      it 'refuses an event handler on an allowed tag' do
        post = build_post('<img src="x.png" onerror="alert(1)">', owner: contributor)

        expect(post).not_to be_valid
      end

      it 'refuses mixed content even when most of it is allowed' do
        post = build_post('<p id="lead" style="color:red" onclick="alert(1)">t</p>', owner: contributor)

        expect(post).not_to be_valid
      end

      it 'refuses a script payload hidden in a style attribute' do
        post = build_post('<p style="width: expression(alert(1))">t</p>', owner: contributor)

        expect(post).not_to be_valid
      end

      it 'refuses a stray HTML comment (only translation markers are comments here)' do
        post = build_post('<p>x</p><!-- hidden -->', owner: contributor)

        expect(post).not_to be_valid
      end

      it 'stores safe HTML byte-for-byte' do
        content = '<p>Text</p><strong>Bold</strong><a href="https://example.com">Link</a><ul><li>Item</li></ul>'
        post = build_post(content, owner: contributor)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'stores structural table markup and layout attributes byte-for-byte' do
        content = '<table><thead><tr><th>H</th></tr></thead>' \
                  '<tbody><tr><td colspan="2">cell</td></tr></tbody></table>' \
                  '<p id="lead" style="color:red">t</p><a href="/x" target="_blank" rel="noopener">l</a>'
        post = build_post(content, owner: contributor)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'refuses a dangerous edit of previously safe content and keeps the stored value' do
        post = build_post('<p>Safe content</p>', owner: contributor)
        post.save!

        expect(post.update(content: script_content)).to be false
        expect(post.reload.content).to eq('<p>Safe content</p>')
      end

      it 'leaves pre-gate stored content editable when the content itself is untouched' do
        post = build_post('<p>ok</p>', owner: contributor)
        post.save!
        post.update_column(:content, script_content) # rubocop:disable Rails/SkipsModelValidations

        expect(post.update(title: 'New title')).to be true
      end

      # Audit M1: markup smuggled through an attribute value (entity-encoded so no literal "<" is
      # stored) still reaches the DOM through a client-side data-html sink -- refuse it.
      it 'refuses entity-encoded markup smuggled through a data attribute' do
        post = build_post('<a rel="popover" data-toggle="popover" data-html="true" ' \
                          'data-content="&lt;img src=x onerror=alert(1)&gt;">x</a>', owner: contributor)

        expect(post).not_to be_valid
        expect(post.errors[:content].join).to include('not allowed for your role')
      end

      it 'stores a benign data-* attribute unchanged' do
        content = '<span data-toggle="tooltip" aria-label="hi" title="plain">hi</span>'
        post = build_post(content, owner: contributor)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      # Audit M16: the size ceiling now refuses with a size-specific message (an over-size value may
      # be perfectly clean), and a long clean post that the old 64 KiB cap refused now saves.
      it 'refuses over-size content with a size-specific message, not the markup message' do
        post = build_post("<p>#{'a' * (CamaleonCms::UnsafeMarkup::MAX_GATED_VALUE_BYTES + 10)}</p>",
                          owner: contributor)

        expect(post).not_to be_valid
        expect(post.errors[:content].join).to include('too large')
        expect(post.errors[:content].join).not_to include('scripts')
      end

      it 'stores a long clean post that exceeds the old 64 KiB cap' do
        content = "<p>#{'word ' * 20_000}</p>"
        post = build_post(content, owner: contributor)

        expect(content.bytesize).to be > 64 * 1024
        expect(post.save).to be true
      end
    end

    context 'with translation markers and lookalikes in untrusted content' do
      before { assign_current_user(contributor) }

      it 'stores literal !-- / --! typed by a user (they are not comment delimiters)' do
        content = '<p>Big Sale !-- 50% off --!</p>'
        post = build_post(content, owner: contributor)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'stores multilingual locale markers byte-for-byte' do
        content = '<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->'
        post = build_post(content, owner: contributor)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'refuses a translation marker placed inside a tag' do
        post = build_post('<p title="<!--:en-->x">t</p>', owner: contributor)

        expect(post).not_to be_valid
      end
    end

    context 'when the author holds post_content_unfiltered_html' do
      it 'stores script content verbatim for an admin' do
        assign_current_user(admin)
        content = '<p>Content</p><script>validAppCode()</script>'
        post = build_post(content, owner: admin)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'stores iframes verbatim for an admin' do
        assign_current_user(admin)
        content = '<iframe src="https://example.com/embed"></iframe>'
        post = build_post(content, owner: admin)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'trusts a non-admin role granted the capability for the post type' do
        editor = create(:user, role: 'editor', site: site)
        site.user_roles.find_by(slug: 'editor')
            .set_meta("_post_type_#{site.id}", edit: [post_type.id], post_content_unfiltered_html: [post_type.id])
        assign_current_user(editor)
        content = '<p>Content</p><script>validAppCode()</script>'
        post = build_post(content, owner: editor)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end

      it 'still refuses for a non-admin role without the grant' do
        editor = create(:user, role: 'editor', site: site)
        site.user_roles.find_by(slug: 'editor').set_meta("_post_type_#{site.id}", edit: [post_type.id])
        assign_current_user(editor)

        expect(build_post(script_content, owner: editor)).not_to be_valid
      end
    end

    context 'when user context is absent (fail closed)' do
      it 'refuses dangerous content with no user set' do
        CurrentRequest.user = nil
        CurrentRequest.site = site

        expect(build_post(script_content)).not_to be_valid
      end

      it 'refuses dangerous content when the site context is missing, without raising' do
        CurrentRequest.user = contributor
        CurrentRequest.site = nil
        post = build_post(script_content, owner: contributor)

        expect { post.valid? }.not_to raise_error
        expect(post).not_to be_valid
      end

      it 'still saves benign content with no context at all' do
        content = '<p>Plain seeded content</p>'
        post = build_post(content)

        expect(post.save).to be true
        expect(post.reload.content).to eq(content)
      end
    end

    context 'with the developer opt-out' do
      it 'stores raw content when unfiltered_content! is set and no user context exists' do
        post = build_post('<p>seed</p><script>seed()</script>')
        post.unfiltered_content!

        expect(post.save).to be true
        expect(post.reload.content).to include('<script>seed()</script>')
      end

      it 'stays enabled for later saves of the same instance' do
        post = build_post('<p>seed</p>')
        post.unfiltered_content!
        post.save!
        post.update!(content: '<p>again</p><script>again()</script>')

        expect(post.reload.content).to include('<script>again()</script>')
      end

      it 'has no mass-assignment writer' do
        expect { described_class.new(unfiltered_content: true) }
          .to raise_error(ActiveModel::UnknownAttributeError)
      end
    end
  end
end
