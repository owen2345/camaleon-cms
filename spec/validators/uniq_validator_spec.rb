# frozen_string_literal: true

RSpec.describe CamaleonCms::UniqValidator, type: :model do
  init_site

  let(:existing_role) { CamaleonCms::UserRole.find_by!(slug: 'admin', parent_id: @site.id) }

  it 'rejects a record whose slug duplicates another under the same parent and taxonomy' do
    duplicate = CamaleonCms::UserRole.new(name: 'Duplicate Admin', slug: 'admin',
                                          taxonomy: 'user_roles', parent_id: existing_role.parent_id)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:base])
      .to include(I18n.t('camaleon_cms.admin.post.message.requires_different_slug').to_s)
  end

  it 'accepts the same slug under a different parent' do
    other_parent = create(:post_type)
    same_slug_elsewhere = CamaleonCms::UserRole.new(name: 'Other Admin', slug: 'admin',
                                                    taxonomy: 'user_roles', parent_id: other_parent.id)

    expect(same_slug_elsewhere).to be_valid
  end

  it 'accepts re-validating the record that owns the slug' do
    expect(existing_role).to be_valid
  end
end
