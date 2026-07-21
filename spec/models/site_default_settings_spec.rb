# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SiteDefaultSettings, type: :model do
  describe 'default role seeding of allow_unfiltered_html' do
    let(:site) { create(:site) }
    let!(:post_type) { create(:post_type, site: site) }

    def perms_for(slug)
      site.user_roles.find_by(slug: slug).get_meta("_post_type_#{site.id}", {})
    end

    it 'does not grant allow_unfiltered_html to the default editor role (per-post-type branch)' do
      site.set_default_user_roles(post_type)

      perms = perms_for('editor')
      expect(perms[:edit]).to include(post_type.id) # editor still gets its normal permissions
      expect(perms[:allow_unfiltered_html]).to be_blank # but never unfiltered HTML
    end

    it 'does not grant allow_unfiltered_html to the default editor role (bulk branch)' do
      site.set_default_user_roles

      expect(perms_for('editor')[:allow_unfiltered_html]).to be_blank
    end

    it 'does not grant allow_unfiltered_html to the default contributor role' do
      site.set_default_user_roles(post_type)

      expect(perms_for('contributor')[:allow_unfiltered_html]).to be_blank
    end
  end
end
