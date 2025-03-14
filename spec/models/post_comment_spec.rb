# frozen_string_literal: true

require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::PostComment, type: :model do
  it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[content]
end
