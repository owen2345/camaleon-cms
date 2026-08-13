# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M9): the engine appends credential-bearing parameter names to
# config.filter_parameters, so the site-settings SMTP password and S3 keys (submitted as
# options[email_pass] / options[filesystem_s3_access_key] / options[filesystem_s3_secret_key]) and user
# passwords are redacted from the Rails logs instead of written in the clear.
RSpec.describe CamaleonCms::Engine do
  describe 'log parameter filtering' do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }
    let(:params) do
      {
        'options' => {
          'email_pass' => 'smtp-secret',
          'filesystem_s3_access_key' => 'AKIA-access',
          'filesystem_s3_secret_key' => 's3-secret',
          'site_name' => 'My Site'
        },
        'password' => 'hunter2'
      }
    end

    it 'redacts the SMTP password, both S3 keys, and the user password' do
      filtered = filter.filter(params)

      expect(filtered['options']['email_pass']).to eq('[FILTERED]')
      expect(filtered['options']['filesystem_s3_access_key']).to eq('[FILTERED]')
      expect(filtered['options']['filesystem_s3_secret_key']).to eq('[FILTERED]')
      expect(filtered['password']).to eq('[FILTERED]')
    end

    it 'leaves non-sensitive settings readable' do
      filtered = filter.filter(params)

      expect(filtered['options']['site_name']).to eq('My Site')
    end

    it 'redacts the installer setup token and a protected post password' do
      filtered = filter.filter({ 'setup_token' => 'gate-secret',
                                 'post' => { 'visibility_value' => 'post-pass' } })

      expect(filtered['setup_token']).to eq('[FILTERED]')
      expect(filtered['post']['visibility_value']).to eq('[FILTERED]')
    end
  end
end
