# frozen_string_literal: true

# Security (gate-content-shortcodes): a shortcode in authored content triggers theme/plugin code
# that emits arbitrary HTML/JS at render, which the save-time content scan cannot judge (the
# shortcode registry is populated per frontend request, output is dynamic, and after expansion the
# theme-emitted markup is indistinguishable from author input). So an author lacking
# post_content_unfiltered_html can still emit a <script> through a shortcode -- an end-run around
# that gate. Because no scan can judge a shortcode, the sanctioned remedy under
# security-capability-gating is a default-off permission (content_shortcodes), enforced by a
# save-time rejection across every surface do_shortcode expands: post content, custom-field values,
# taxonomy content and widget descriptions. Rendering is unchanged -- stored content stays verbatim.
#
# `[widget ...]` is a core-registered shortcode, used here as a concrete registered name; the
# real-world threat is a frontend/plugin shortcode such as `[redirect url="';alert(...);//"]`
# (audit WEB-2) that a theme expands to a <script> for every viewer.
RSpec.describe 'Content shortcode gating', type: :model do
  let(:site) { create(:site) }
  let(:post_type) { create(:post_type, site: site) }
  let(:admin) { create(:user, role: 'admin', site: site) }
  let(:contributor) { create(:user, role: 'contributor', site: site) }
  let(:shortcode_content) { 'Intro [widget my_widget] outro' }

  def as_user(user)
    CurrentRequest.user = user
    CurrentRequest.site = site
  end

  def grant_content_shortcodes(role_slug)
    role = site.user_roles.find_by(slug: role_slug)
    meta = role.get_meta("_manager_#{site.id}", {}) || {}
    role.set_meta("_manager_#{site.id}", meta.merge('content_shortcodes' => 1))
  end

  after do
    CurrentRequest.user = nil
    CurrentRequest.site = nil
    CurrentRequest.shortcodes = nil
    CurrentRequest.shortcodes_template = nil
  end

  describe 'post content (Post#content)' do
    def build_post(content, owner: nil)
      build(:post, post_type: post_type, owner: owner, content: content)
    end

    it 'refuses a non-administrator without content_shortcodes and stores nothing' do
      as_user(contributor)
      post = build_post(shortcode_content, owner: contributor)

      expect(post).not_to be_valid
      expect(post.errors[:base].join).to match(/shortcode/i)
      expect(post.save).to be false
    end

    it 'still allows the same author to save shortcode-free content' do
      as_user(contributor)
      post = build_post('<p>Just prose, and even [bracketed] text</p>', owner: contributor)

      expect(post.save).to be true
    end

    it 'allows a non-administrator granted content_shortcodes' do
      editor = create(:user, role: 'editor', site: site)
      grant_content_shortcodes('editor')
      as_user(editor)
      post = build_post(shortcode_content, owner: editor)

      expect(post.save).to be true
      expect(post.reload.content).to eq(shortcode_content)
    end

    it 'allows an administrator without the key present in role meta' do
      as_user(admin)
      post = build_post(shortcode_content, owner: admin)

      expect(post.save).to be true
      expect(post.reload.content).to eq(shortcode_content)
    end

    it 'refuses a dangerous edit of previously safe content and keeps the stored value' do
      as_user(contributor)
      post = build_post('<p>safe</p>', owner: contributor)
      post.save!

      expect(post.update(content: shortcode_content)).to be false
      expect(post.reload.content).to eq('<p>safe</p>')
    end

    it 'leaves pre-gate stored shortcode content editable when the content itself is untouched' do
      as_user(contributor)
      post = build_post('<p>ok</p>', owner: contributor)
      post.save!
      post.update_column(:content, shortcode_content) # rubocop:disable Rails/SkipsModelValidations

      expect(post.update(title: 'New title')).to be true
    end
  end

  describe 'custom-field values (CustomFieldsRelationship#value)' do
    let(:post) { create(:post, post_type: post_type, owner: admin) }

    before do
      group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields',
                                                    object_class: 'PostType_Post', objectid: post_type.id,
                                                    site: site)
      group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
    end

    it 'refuses a shortcode in a plain text_box value for a non-administrator' do
      as_user(contributor)

      expect { post.set_field_value('note', shortcode_content) }
        .to raise_error(ActiveRecord::RecordInvalid, /shortcode/i)
      expect(post.get_field_value('note')).to be_blank
    end

    it 'stores the same value verbatim for an administrator' do
      as_user(admin)

      post.set_field_value('note', shortcode_content)

      expect(post.get_field_value('note')).to eq(shortcode_content)
    end

    it 'allows a non-administrator granted content_shortcodes' do
      editor = create(:user, role: 'editor', site: site)
      grant_content_shortcodes('editor')
      as_user(editor)

      post.set_field_value('note', shortcode_content)

      expect(post.get_field_value('note')).to eq(shortcode_content)
    end
  end

  describe 'taxonomy content (TermTaxonomy#description)' do
    it 'refuses a shortcode in a post-type description for a non-administrator' do
      as_user(contributor)
      taxonomy = build(:post_type, site: site, description: shortcode_content)

      expect(taxonomy).not_to be_valid
      expect(taxonomy.errors[:base].join).to match(/shortcode/i)
    end

    it 'allows an administrator' do
      as_user(admin)
      taxonomy = build(:post_type, site: site, description: shortcode_content)

      expect(taxonomy.save).to be true
    end
  end

  describe 'widget descriptions (Widget::Main#description, a TermTaxonomy STI subclass)' do
    it 'refuses a shortcode in a widget description for a non-administrator' do
      as_user(contributor)
      widget = site.widgets.new(name: 'W', slug: 'w', description: shortcode_content)

      expect(widget).not_to be_valid
      expect(widget.errors[:base].join).to match(/shortcode/i)
    end

    it 'allows an administrator' do
      as_user(admin)
      widget = site.widgets.new(name: 'W', slug: 'w', description: shortcode_content)

      expect(widget.save).to be true
    end
  end

  # 3.3 coverage: every do_shortcode-expanded surface maps to a model including the shared gate, so a
  # newly added expanded surface that forgets the gate is caught here. Post#content, custom-field
  # values and TermTaxonomy#description (which STI-covers taxonomy content AND widget descriptions)
  # are the known set today.
  describe 'gate coverage across expanded surfaces (3.3)' do
    it 'includes the shared gate in every model whose content do_shortcode expands' do
      [CamaleonCms::Post, CamaleonCms::TermTaxonomy, CamaleonCms::CustomFieldsRelationship].each do |model|
        expect(model.ancestors).to include(CamaleonCms::ContentShortcodeGate),
                                   "#{model} must include ContentShortcodeGate to gate its shortcode-expanded content"
      end
    end

    it 'STI-covers taxonomy and widget subclasses through TermTaxonomy' do
      [CamaleonCms::PostType, CamaleonCms::Category, CamaleonCms::PostTag,
       CamaleonCms::Widget::Main, CamaleonCms::Widget::Sidebar].each do |model|
        expect(model.ancestors).to include(CamaleonCms::ContentShortcodeGate)
      end
    end
  end

  describe 'security-capability-gating conformance' do
    it 'reads an absent key as not-granted for an upgraded install (no migration)' do
      # A role whose stored manager meta predates the permission: the key is simply absent.
      legacy = create(:user, role: 'editor', site: site)
      site.user_roles.find_by(slug: 'editor').set_meta("_manager_#{site.id}", { 'media' => 1 })

      expect(CamaleonCms::Ability.new(legacy, site).can?(:manage, :content_shortcodes)).to be false
    end

    it 'grants the capability once the key is present and truthy' do
      editor = create(:user, role: 'editor', site: site)
      grant_content_shortcodes('editor')

      expect(CamaleonCms::Ability.new(editor, site).can?(:manage, :content_shortcodes)).to be true
    end

    it 'exposes content_shortcodes as a danger-flagged manager permission in the roles UI list' do
      keys = CamaleonCms::UserRole::ROLES[:manager].map { |perm| perm[:key] }
      perm = CamaleonCms::UserRole::ROLES[:manager].find { |p| p[:key] == 'content_shortcodes' }

      expect(keys).to include('content_shortcodes')
      expect(perm[:color]).to eq('danger')
    end

    context 'when the gate cannot fully evaluate (fail-closed)' do
      def build_post(content, owner: nil)
        build(:post, post_type: post_type, owner: owner, content: content)
      end

      it 'refuses shortcode content with no user context (job/rake/console)' do
        CurrentRequest.user = nil
        CurrentRequest.site = site

        expect(build_post(shortcode_content)).not_to be_valid
      end

      it 'refuses shortcode content when the site context is missing, without raising' do
        CurrentRequest.user = contributor
        CurrentRequest.site = nil
        post = build_post(shortcode_content, owner: contributor)

        expect { post.valid? }.not_to raise_error
        expect(post).not_to be_valid
      end

      it 'resolves to gated for a non-administrator when the registry is unavailable' do
        post_type # force factory creation while the registry is still available
        as_user(contributor)
        allow(CamaleonCms::ShortcodeRegistry).to receive(:available?).and_return(false)
        # An unavailable registry treats any non-blank content as gated: even plain prose is refused
        # for a non-administrator (fail closed), while an administrator still passes.
        expect(build_post('plain prose', owner: contributor)).not_to be_valid
      end

      it 'still lets an administrator save while the registry is unavailable' do
        post_type
        as_user(admin)
        allow(CamaleonCms::ShortcodeRegistry).to receive(:available?).and_return(false)

        expect(build_post(shortcode_content, owner: admin).save).to be true
      end

      it 'resolves to gated when evaluating the permission raises' do
        # Exercised through TermTaxonomy, which carries only the shortcode gate (no competing HTML
        # gate), so a raising Ability isolates this gate's own fail-closed rescue.
        as_user(contributor) # forces site creation before the stub
        allow(CamaleonCms::Ability).to receive(:new).and_raise(StandardError)
        taxonomy = build(:post_type, site: site, description: shortcode_content)

        expect { taxonomy.valid? }.not_to raise_error
        expect(taxonomy).not_to be_valid
      end
    end
  end

  # 4.6 / 4.7: the gate is a save-time authorization decision only. A permitted author's stored
  # shortcode content is neither escaped nor sanitized on save, and expands byte-for-byte at render.
  describe 'rendering is unchanged (no escaping/sanitizing)' do
    it 'stores a permitted author shortcode value byte-for-byte' do
      as_user(admin)
      raw = %([data key="contact" attr="url"] & <em>x</em> [widget k])
      post = build(:post, post_type: post_type, owner: admin, content: raw)

      expect(post.save).to be true
      expect(post.reload.content).to eq(raw)
    end

    it 'expands the stored shortcode verbatim at render, with no CMS escaping of its output' do
      # do_shortcode runs the registered handler and splices its output back in unchanged: the CMS
      # applies no escaping/sanitizing to the shortcode syntax, attributes or output at render.
      harness = Object.new.extend(CamaleonCms::ShortCodeHelper)
      CurrentRequest.shortcodes = ['demo']
      CurrentRequest.shortcodes_template = { 'demo' => ->(_attrs, _args) { '<b>RAW</b> & "quotes"' } }

      rendered = harness.do_shortcode('before [demo] after')

      expect(rendered).to eq('before <b>RAW</b> & "quotes" after')
    end
  end
end
