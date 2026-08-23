# frozen_string_literal: true
require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::UserRole, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[description]

  describe 'native STI compatibility' do
    it 'uses legacy user_roles taxonomy as sti_name' do
      expect(described_class.sti_name).to eq('user_roles')
    end

    it 'can read default roles created for a site' do
      # default roles are created when a site is installed as the main site;
      # with users_share_sites a secondary site reuses them, so assert on the
      # suite-wide shared (main) site.
      site = CamaleonCms::Site.first.decorate

      expect(described_class.where(parent_id: site.id)).not_to be_empty
    end
  end
end
