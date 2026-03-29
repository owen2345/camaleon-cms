require 'rails_helper'

RSpec.describe CamaleonCms::UserRole, type: :model do
  it "includes a 'select_eval' manager role definition in ROLES" do
    manager_roles = CamaleonCms::UserRole::ROLES[:manager]
    keys = manager_roles.map { |r| r[:key] }
    expect(keys).to include('select_eval')
  end
end
