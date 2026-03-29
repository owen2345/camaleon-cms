require 'rails_helper'

RSpec.describe CamaleonCms::Ability, type: :model do
  init_site

  let(:site) { Cama::Site.first }

  it 'does not allow manage select_eval for a user without permission' do
    user = create(:user, role: 'client', site: site)
    ability = CamaleonCms::Ability.new(user, site)
    expect(ability.can?(:manage, :select_eval)).to be false
  end

  it 'allows manage select_eval for a user with select_eval manager meta' do
    role = site.user_roles.create!(name: 'Select Eval Manager Unit', slug: 'select_eval_unit')
    role.set_meta("_manager_#{site.id}", { select_eval: 1 })
    user = create(:user, role: role.slug, site: site)
    ability = CamaleonCms::Ability.new(user, site)
    expect(ability.can?(:manage, :select_eval)).to be true
  end
end
