# frozen_string_literal: true

# `media_unfiltered_upload` is the manager-family grant that exempts an uploader from the
# malicious-content scan. It is the third member of the unfiltered-content family, after the
# per-post-type `post_content_unfiltered_html` and the manager-level `contact_form_unfiltered_html`
# — the names are similar and the scopes are not, so holding one must never imply another.
RSpec.describe 'media_unfiltered_upload permission', type: :model do
  let!(:site) { create(:site) }

  def ability_for(user)
    CamaleonCms::Ability.new(user, site)
  end

  def role(slug)
    site.user_roles.find_by(slug: slug)
  end

  describe 'the role definition' do
    subject(:entry) do
      CamaleonCms::UserRole::ROLES[:manager].find { |r| r[:key] == 'media_unfiltered_upload' }
    end

    it 'is declared as a manager permission, because the media library is site-wide' do
      expect(entry).to be_present
      expect(CamaleonCms::UserRole::ROLES[:post_type].map { |r| r[:key] }).not_to include('media_unfiltered_upload')
    end

    it 'is flagged as privilege-granting so the role editor renders it as dangerous' do
      expect(entry[:color]).to eq('danger')
    end

    it 'names its subject in the label, so it cannot be confused with the other two grants' do
      expect(entry[:label]).to eq('Allow unscanned media uploads')
    end
  end

  describe 'defaults after a site is seeded' do
    it 'grants it to the admin role through the existing all-manager-keys seeding' do
      expect(role('admin').get_meta("_manager_#{site.id}")).to include('media_unfiltered_upload' => 1)
    end

    # No `next if value[:key] == ...` guard belongs in site_default_settings.rb for this key: unlike
    # ROLES[:post_type], the only roles that receive `_manager_` meta are admin (all keys) and client
    # (empty). Adding the guard would strip the permission from administrators.
    it 'withholds it from every non-admin default role' do
      %w[editor contributor client].each do |slug|
        meta = role(slug)&.get_meta("_manager_#{site.id}") || {}
        expect(meta['media_unfiltered_upload']).to be_blank, "#{slug} unexpectedly holds the grant"
      end
    end

    # Upgrading an existing install must never widen what a role may upload: a stored meta written
    # before this permission existed simply has no key for it.
    it 'reads a role meta written before the permission existed as not granting it' do
      legacy = site.user_roles.create!(name: 'Legacy media', slug: 'legacy-media')
      legacy.set_meta("_manager_#{site.id}", { 'media' => 1 })
      user = create(:user, role: 'legacy-media', site: site)

      expect(ability_for(user).can?(:manage, :media)).to be true
      expect(ability_for(user).can?(:manage, :media_unfiltered_upload)).to be false
    end
  end

  describe 'ability resolution' do
    it 'is satisfied by an administrator via can :manage, :all' do
      admin = create(:user, role: 'admin', site: site)

      expect(ability_for(admin).can?(:manage, :media_unfiltered_upload)).to be true
    end

    it 'is denied to a role that has not been granted it' do
      contributor = create(:user, role: 'contributor', site: site)

      expect(ability_for(contributor).can?(:manage, :media_unfiltered_upload)).to be false
    end

    it 'is granted to a custom role once the manager key is enabled' do
      custom = site.user_roles.create!(name: 'Media trusted', slug: 'media-trusted')
      custom.set_meta("_manager_#{site.id}", { 'media_unfiltered_upload' => 1 })
      user = create(:user, role: 'media-trusted', site: site)

      expect(ability_for(user).can?(:manage, :media_unfiltered_upload)).to be true
    end

    # `manage :media` is what reaches the upload and crop endpoints at all. The whole point of the
    # new grant is that reaching them does not imply skipping the scan.
    it 'is not implied by holding :manage, :media' do
      custom = site.user_roles.create!(name: 'Media manager', slug: 'media-manager')
      custom.set_meta("_manager_#{site.id}", { 'media' => 1 })
      user = create(:user, role: 'media-manager', site: site)

      expect(ability_for(user).can?(:manage, :media)).to be true
      expect(ability_for(user).can?(:manage, :media_unfiltered_upload)).to be false
    end
  end

  describe 'independence from the other unfiltered-content grants' do
    let(:post_type) { create(:post_type, site: site) }

    it 'is not implied by the post-content grant' do
      custom = site.user_roles.create!(name: 'Posts only', slug: 'posts-only')
      custom.set_meta("_post_type_#{site.id}", { 'post_content_unfiltered_html' => [post_type.id] })
      user = create(:user, role: 'posts-only', site: site)

      expect(ability_for(user).can?(:post_content_unfiltered_html, post_type)).to be true
      expect(ability_for(user).can?(:manage, :media_unfiltered_upload)).to be false
    end

    it 'is not implied by the contact-form grant' do
      custom = site.user_roles.create!(name: 'Forms only', slug: 'forms-only')
      custom.set_meta("_manager_#{site.id}", { 'contact_form_unfiltered_html' => 1 })
      user = create(:user, role: 'forms-only', site: site)

      expect(ability_for(user).can?(:manage, :contact_form_unfiltered_html)).to be true
      expect(ability_for(user).can?(:manage, :media_unfiltered_upload)).to be false
    end

    it 'does not imply either of them' do
      custom = site.user_roles.create!(name: 'Uploads only', slug: 'uploads-only')
      custom.set_meta("_manager_#{site.id}", { 'media_unfiltered_upload' => 1 })
      user = create(:user, role: 'uploads-only', site: site)

      expect(ability_for(user).can?(:manage, :contact_form_unfiltered_html)).to be false
      expect(ability_for(user).can?(:post_content_unfiltered_html, post_type)).to be false
    end
  end
end
