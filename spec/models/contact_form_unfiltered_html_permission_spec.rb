# frozen_string_literal: true

require 'rails_helper'

# `contact_form_unfiltered_html` is the manager-family grant that exempts the contact-form plugin's
# four markup-by-contract settings from save-time sanitization. It is deliberately separate from the
# post-type grant `post_content_unfiltered_html`, which governs `Post#content`: the names are similar
# and the scopes are not, so holding one must never imply the other.
RSpec.describe 'contact_form_unfiltered_html permission', type: :model do
  let!(:site) { create(:site) }

  def ability_for(user)
    CamaleonCms::Ability.new(user, site)
  end

  def role(slug)
    site.user_roles.find_by(slug: slug)
  end

  describe 'the role definition' do
    subject(:entry) do
      CamaleonCms::UserRole::ROLES[:manager].find { |r| r[:key] == 'contact_form_unfiltered_html' }
    end

    it 'is declared as a manager permission' do
      expect(entry).to be_present
    end

    it 'is flagged as privilege-granting so the role editor renders it as dangerous' do
      expect(entry[:color]).to eq('danger')
    end

    it 'names its subject in the label, so it cannot be confused with the post-content grant' do
      post_content = CamaleonCms::UserRole::ROLES[:post_type]
                     .find { |r| r[:key] == 'post_content_unfiltered_html' }

      expect(entry[:label]).to eq('Allow unfiltered HTML in contact forms')
      expect(post_content[:label]).to eq('Allow unfiltered HTML in post content')
    end
  end

  describe 'defaults after a site is seeded' do
    it 'grants it to the admin role through the existing all-manager-keys seeding' do
      expect(role('admin').get_meta("_manager_#{site.id}")).to include('contact_form_unfiltered_html' => 1)
    end

    # No `next if value[:key] == ...` guard belongs in site_default_settings.rb for this key: unlike
    # ROLES[:post_type], the only roles that receive `_manager_` meta are admin (all keys) and client
    # (empty). Adding the guard would strip the permission from administrators.
    it 'withholds it from every non-admin default role' do
      %w[editor contributor client].each do |slug|
        meta = role(slug)&.get_meta("_manager_#{site.id}") || {}
        expect(meta['contact_form_unfiltered_html']).to be_blank, "#{slug} unexpectedly holds the grant"
      end
    end
  end

  describe 'ability resolution' do
    it 'is satisfied by an administrator via can :manage, :all' do
      admin = create(:user, role: 'admin', site: site)

      expect(ability_for(admin).can?(:manage, :contact_form_unfiltered_html)).to be true
    end

    it 'is denied to a role that has not been granted it' do
      contributor = create(:user, role: 'contributor', site: site)

      expect(ability_for(contributor).can?(:manage, :contact_form_unfiltered_html)).to be false
    end

    it 'is granted to a custom role once the manager key is enabled' do
      custom = site.user_roles.create!(name: 'Forms editor', slug: 'forms-editor')
      custom.set_meta("_manager_#{site.id}", { 'contact_form_unfiltered_html' => 1 })
      user = create(:user, role: 'forms-editor', site: site)

      expect(ability_for(user).can?(:manage, :contact_form_unfiltered_html)).to be true
    end

    it 'is not implied by holding :manage, :plugins — the privilege the escalation starts from' do
      custom = site.user_roles.create!(name: 'Plugins manager', slug: 'plugins-manager')
      custom.set_meta("_manager_#{site.id}", { 'plugins' => 1 })
      user = create(:user, role: 'plugins-manager', site: site)

      expect(ability_for(user).can?(:manage, :plugins)).to be true
      expect(ability_for(user).can?(:manage, :contact_form_unfiltered_html)).to be false
    end
  end

  describe 'independence from the post-content grant' do
    let(:post_type) { create(:post_type, site: site) }

    after do
      CurrentRequest.user = nil
      CurrentRequest.site = nil
    end

    it 'does not let the contact-form grant bypass post content sanitization' do
      custom = site.user_roles.create!(name: 'Forms only', slug: 'forms-only')
      custom.set_meta("_manager_#{site.id}", { 'contact_form_unfiltered_html' => 1 })
      user = create(:user, role: 'forms-only', site: site)
      CurrentRequest.user = user
      CurrentRequest.site = site

      post = create(:post, post_type: post_type, owner: user,
                           content: '<p>Hi</p><script>alert(1)</script>')

      expect(post.content).not_to include('<script>')
      expect(post.content).to include('<p>Hi</p>')
    end

    it 'does not let the post-content grant satisfy the contact-form check' do
      custom = site.user_roles.create!(name: 'Posts only', slug: 'posts-only')
      custom.set_meta("_post_type_#{site.id}", { 'post_content_unfiltered_html' => [post_type.id] })
      user = create(:user, role: 'posts-only', site: site)

      expect(ability_for(user).can?(:post_content_unfiltered_html, post_type)).to be true
      expect(ability_for(user).can?(:manage, :contact_form_unfiltered_html)).to be false
    end
  end
end
