# frozen_string_literal: true

require 'shared_specs/hook_handler_dispatch'

RSpec.describe CamaleonCms::HookLifecycleConcern do
  it_behaves_like 'a hook handler dispatcher', described_class
end
