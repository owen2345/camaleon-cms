# frozen_string_literal: true

require 'rails_helper'

# N2: before_upload fires AFTER the content scan and can rebind settings[:uploaded_io], so a
# handler could launder blocked bytes past the scanner. For an untrusted uploader the pipeline
# must re-scan the substituted IO. Exercised directly against upload_file through a minimal
# host, with the trust gate stubbed to model an untrusted vs. permitted uploader.
RSpec.describe 'Security: before_upload re-scan', type: :request do
  init_site

  let(:site) { Cama::Site.first }

  let(:host_class) do
    Class.new do
      include CamaleonCms::UploaderContentSecurity
      include CamaleonCms::UploaderPathSecurity
      include CamaleonCms::UploaderPipeline
      include CamaleonCms::UploaderImageProcessing
      include CamaleonCms::UploaderSupport

      attr_accessor :site

      def current_site
        site
      end

      def hooks_run(key, params = nil)
        PluginRoutes.get_anonymous_hooks(key).each { |h| h.call(params) }
      end
    end
  end

  let(:host) { host_class.new.tap { |h| h.site = site.decorate } }

  # A clean source file the initial scan passes.
  let(:clean_source) do
    path = File.join(Dir.mktmpdir, 'clean.txt')
    File.write(path, 'perfectly harmless text')
    path
  end

  # Bytes a before_upload handler swaps in after the scan.
  let(:malicious_bytes) { '<script>alert(document.cookie)</script>' }

  def swap_io_after_hook
    PluginRoutes.add_anonymous_hook('before_upload', lambda { |settings|
      evil = Tempfile.new(['rewritten', '.html'])
      evil.write(malicious_bytes)
      evil.rewind
      settings[:uploaded_io] = evil
    }, 'spec-n2-swap')
  end

  after { PluginRoutes.remove_anonymous_hook('before_upload', 'spec-n2-swap') }

  context 'when the uploader is untrusted' do
    before { allow(host).to receive(:cama_trusted_for_unfiltered_upload?).and_return(false) }

    it 'refuses the upload when a handler substitutes blocked bytes' do
      swap_io_after_hook
      result = host.upload_file(clean_source, folder: 'spec_n2')

      expect(result[:error]).to match(/malicious/i)
    end

    it 'never reaches the persistence step for substituted blocked bytes' do
      swap_io_after_hook
      expect(host.cama_uploader).not_to receive(:add_file)

      host.upload_file(clean_source, folder: 'spec_n2')
    end

    it 'stores an upload when no handler substitutes the IO' do
      result = host.upload_file(clean_source, folder: 'spec_n2')

      expect(result[:error]).to be_nil
    end
  end

  context 'when the uploader holds the permission' do
    before { allow(host).to receive(:cama_trusted_for_unfiltered_upload?).and_return(true) }

    it 'persists the substituted bytes without a re-scan' do
      swap_io_after_hook
      result = host.upload_file(clean_source, folder: 'spec_n2')

      expect(result[:error]).to be_nil
    end
  end
end
