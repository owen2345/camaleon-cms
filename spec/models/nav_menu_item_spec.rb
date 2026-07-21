# frozen_string_literal: true

require 'rails_helper'
require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::NavMenuItem, type: :model do
  before { allow_any_instance_of(described_class).to receive(:update_count) }

  # name (the menu label) is rendered as raw/trusted HTML, so it keeps save-time sanitization
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]
end
