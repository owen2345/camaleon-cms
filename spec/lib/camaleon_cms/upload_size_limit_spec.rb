# frozen_string_literal: true

require 'rails_helper'

# M26: a stored filesystem_max_size of 0 (blank/zeroed setting) must not reject every upload.
# cama_size_limit_error is the single gate every caller — core and cama_contact_form's
# maximum: pass-through — flows through, so the fix lands here.
RSpec.describe CamaleonCms::UploaderPipeline do
  let(:host) do
    Class.new do
      include CamaleonCms::UploaderPipeline

      # cama_size_limit_error needs the message seam; the concern's I18n default suffices here.
      def cama_uploader_human_size(bytes)
        ActiveSupport::NumberHelper.number_to_human_size(bytes)
      end

      def cama_uploader_ct(key, args = {})
        I18n.t("camaleon_cms.common.#{key}", **args)
      end
    end.new
  end

  describe '#cama_size_limit_error' do
    it 'treats a zero maximum as unlimited' do
      expect(host.send(:cama_size_limit_error, 5.megabytes, 0)).to be_nil
    end

    it 'treats a negative maximum as unlimited' do
      expect(host.send(:cama_size_limit_error, 5.megabytes, -1)).to be_nil
    end

    it 'still rejects a file above a positive maximum' do
      error = host.send(:cama_size_limit_error, 5.megabytes, 1.megabyte)
      # Assert the contract (an error is returned), not the locale-dependent message text, so a
      # leaked I18n.locale from another example cannot flip this.
      expect(error[:error]).to be_present
    end

    it 'accepts a file within a positive maximum' do
      expect(host.send(:cama_size_limit_error, 1.megabyte, 5.megabytes)).to be_nil
    end

    it 'treats a blank maximum as unlimited' do
      expect(host.send(:cama_size_limit_error, 5.megabytes, nil)).to be_nil
    end
  end
end
