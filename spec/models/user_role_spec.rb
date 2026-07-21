# frozen_string_literal: true

require 'rails_helper'
require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::UserRole, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[description]

  describe 'native STI compatibility' do
    it 'uses legacy user_roles taxonomy as sti_name' do
      expect(described_class.sti_name).to eq('user_roles')
    end

    it 'can read default roles created for a site' do
      site = create(:site).decorate

      expect(described_class.where(parent_id: site.id)).not_to be_empty
    end
  end
end
