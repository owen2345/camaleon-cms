# frozen_string_literal: true

RSpec.describe 'Meta scope resolution', type: :model do
  init_site

  def host_class
    # Name the class before including the concern — the scope name is captured at include time
    Class.new(::CamaleonRecord) { self.table_name = CamaleonCms::User.table_name }
  end

  it 'demodulizes engine classes' do
    expect(CamaleonCms::Post.new.metas.build.object_class).to eq('Post')
  end

  it 'demodulizes nested engine classes (the widget scopes)' do
    expect(CamaleonCms::Widget::Main.new.metas.build.object_class).to eq('Main')
  end

  it 'demodulizes namespaced host classes' do
    stub_const('SpecHost::Member', host_class)
    SpecHost::Member.include(CamaleonCms::CommonRelationships)

    expect(SpecHost::Member.new.metas.build.object_class).to eq('Member')
  end

  it 'keeps unnamespaced host classes as-is' do
    stub_const('SpecMember', host_class)
    SpecMember.include(CamaleonCms::CommonRelationships)

    expect(SpecMember.new.metas.build.object_class).to eq('SpecMember')
  end

  describe '#get_user_field_groups' do
    let(:site) { Cama::Site.first }

    # The user-page read must query the same demodulized name the association scope and the
    # save filter use — a qualified name here is how namespaced-host installs lost their
    # user field values (audit N5).
    it 'derives the demodulized name for a namespaced host user model' do
      stub_const('SpecHost::Member', host_class)
      SpecHost::Member.include(CamaleonCms::CustomFieldsRead)

      expect(SpecHost::Member.new.get_user_field_groups(site).new.object_class).to eq('Member')
    end

    it 'finds groups placed on users under the demodulized name' do
      stub_const('SpecHost::Member', host_class)
      SpecHost::Member.include(CamaleonCms::CustomFieldsRead)
      group = site.custom_field_groups.create!(
        name: 'Member Fields', slug: '_member-fields', object_class: 'Member', objectid: site.id
      )

      expect(SpecHost::Member.new.get_user_field_groups(site).map(&:id)).to include(group.id)
    end

    it 'keeps the engine user model on User' do
      expect(CamaleonCms::User.new.get_user_field_groups(site).new.object_class).to eq('User')
    end
  end
end
