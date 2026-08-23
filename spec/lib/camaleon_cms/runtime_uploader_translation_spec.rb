# frozen_string_literal: true

# M24: media-manager (controller) upload errors must run the on_translation hook. The controller
# chain carries `ct` (restored by #1223), so the concern's cama_uploader_ct routes through it;
# a non-controller includer (no ct) keeps the I18n default.
RSpec.describe CamaleonCms::RuntimeUploaderConcern do
  describe '#cama_uploader_ct' do
    context 'when the host responds to ct (controller-like)' do
      let(:host) do
        Class.new do
          include CamaleonCms::RuntimeUploaderConcern

          # Stand-in for CamaleonHelper#ct: runs on_translation and returns an override when set.
          def ct(key, args = {})
            r = { flag: false, key: key, translation: '', locale: :en }
            hooks_run('on_translation', r)
            return r[:translation] if r[:flag]

            I18n.t("camaleon_cms.common.#{key}", **args)
          end

          def hooks_run(_key, params = nil)
            params[:flag] = true
            params[:translation] = 'PLUGIN OVERRIDE'
          end
        end.new
      end

      it 'routes the message through ct so on_translation can override it' do
        expect(host.send(:cama_uploader_ct, 'file_size_exceeded', default: 'File size exceeded'))
          .to eq('PLUGIN OVERRIDE')
      end
    end

    context 'when the host does not respond to ct' do
      let(:host) { Class.new { include CamaleonCms::RuntimeUploaderConcern }.new }

      it 'falls back to the I18n default' do
        expect(host.respond_to?(:ct, true)).to be(false)
        expect(host.send(:cama_uploader_ct, 'file_size_exceeded', default: 'File size exceeded'))
          .to eq(I18n.t('camaleon_cms.common.file_size_exceeded', default: 'File size exceeded'))
      end
    end
  end
end
