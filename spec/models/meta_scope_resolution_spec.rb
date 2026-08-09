# frozen_string_literal: true

require 'rails_helper'

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
end
