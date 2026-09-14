# frozen_string_literal: true

# A record memoizes its meta and option reads per instance. Copies made with dup shared the original's
# memo, and with it their common nil-id keys, so one copy's option write showed in the others; reload kept
# the values read before it.
RSpec.describe CamaleonRecord do
  let(:post_type) { CamaleonCms::Site.first.post_types.find_by!(slug: 'post') }

  describe '#dup' do
    it 'keeps an option written on one copy out of another' do
      post = build(:post, post_type: post_type)
      # materializes the memo on the original: copies of a record that has read nothing build their own
      post.get_option('has_comments')
      first_copy = post.dup
      second_copy = post.dup

      first_copy.set_option('has_comments', true)

      expect(second_copy.get_option('has_comments')).to be_nil
    end

    it 'starts a copy of an unsaved record without its unsaved metas' do
      post = build(:post, post_type: post_type)
      post.set_meta('subtitle', 'draft')
      copy = post.dup

      expect(copy.get_meta('subtitle')).to be_nil
      expect(copy.metas).to be_empty
    end
  end

  describe '#reload' do
    it 'reads a meta written through another instance since the last read' do
      post = create(:post, post_type: post_type)
      post.set_meta('subtitle', 'old')
      post.get_meta('subtitle')
      CamaleonCms::Post.find(post.id).set_meta('subtitle', 'new')

      expect(post.reload.get_meta('subtitle')).to eq('new')
    end

    it 'keeps the memo when the reload fails' do
      post = create(:post, post_type: post_type)
      post.set_meta('subtitle', 'old')
      CamaleonCms::Post.find(post.id).destroy

      expect { post.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(post.get_meta('subtitle')).to eq('old')
    end

    it 'drops every value memoized through cama_fetch_cache' do
      post = create(:post, post_type: post_type)
      post.cama_fetch_cache('probe') { 'first' }

      expect(post.reload.cama_fetch_cache('probe') { 'second' }).to eq('second')
    end

    it 'passes the lock option on to the record lookup' do
      post = create(:post, post_type: post_type)
      expect(post).to receive(:_find_record).with(hash_including(lock: true)).and_call_original

      post.lock!
    end

    describe 'the permission state read from the record' do
      let(:site) { CamaleonCms::Site.first }

      after { CurrentRequest.reset }

      it 'rebuilds the ability from the role metas stored since' do
        role = site.user_roles.create!(name: 'Probe', slug: "probe_#{SecureRandom.hex(3)}")
        user = create(:user, role: role.slug, site: site)
        set_current(user: user, site: site)
        expect(user.can?(:manage, :custom_fields)).to be(false)

        role.set_meta("_manager_#{site.id}", { custom_fields: 1 })

        expect(user.reload.can?(:manage, :custom_fields)).to be(true)
      end

      it 'reads the role assigned to a user since' do
        user = create(:user, role: 'contributor', site: site)
        expect(user.get_role(site).slug).to eq('contributor')

        CamaleonCms::User.find(user.id).update!(role: 'editor')

        expect(user.reload.get_role(site).slug).to eq('editor')
      end

      it "checks a post's permissions against the request's user and site" do
        role = site.user_roles.create!(name: 'Probe', slug: "probe_#{SecureRandom.hex(3)}")
        user = create(:user, role: role.slug, site: site)
        set_current(user: user, site: site)
        post = create(:post, post_type: post_type)
        expect(post.current_user).to eq(user)
        expect(post.can?(:manage, :custom_fields)).to be(false)

        role.set_meta("_manager_#{site.id}", { custom_fields: 1 })

        expect(post.reload.can?(:manage, :custom_fields)).to be(true)
      end
    end
  end

  describe '#cama_clear_cache' do
    it 'drops every value the instance memoized' do
      post = build(:post)
      post.cama_fetch_cache('probe') { 'first' }
      post.cama_set_cache('other', 'set')

      post.cama_clear_cache

      expect(post.cama_get_cache('other')).to be_nil
      expect(post.cama_fetch_cache('probe') { 'second' }).to eq('second')
    end
  end
end
