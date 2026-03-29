# frozen_string_literal: true

require 'rails_helper'

# The select_eval partial uses instance_eval on the stored command.
# Security is enforced at the controller level via the :custom_fields role permission
# (CamaleonCms::Admin::Settings::CustomFieldsController#validate_role).
# Only users granted the custom_fields manager role can create or edit select_eval fields.
RSpec.describe 'camaleon_cms/admin/settings/custom_fields/fields/_select_eval.html.erb', type: :view do
  let(:field_name) { 'custom_field' }
  let(:field) { Struct.new(:slug, :options).new('test_slug', { command: command, required: false }) }

  before do
    allow(view).to receive(:field_name).and_return(field_name)
    assign(:field, field)
  end

  def render_partial
    render partial: 'camaleon_cms/admin/settings/custom_fields/fields/select_eval',
           locals: { field: field, field_name: field_name }
  end

  context 'when the command returns a plain array' do
    let(:command) { '["one", "two"]' }

    it 'renders select with those options' do
      render_partial
      expect(rendered).to match(/one/)
      expect(rendered).to match(/two/)
    end
  end

  context 'when the command is a Ruby expression' do
    let(:command) { '%w[red green blue]' }

    it 'evaluates and renders the options' do
      render_partial
      expect(rendered).to match(/red/)
      expect(rendered).to match(/green/)
      expect(rendered).to match(/blue/)
    end
  end
end
