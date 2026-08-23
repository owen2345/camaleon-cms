# frozen_string_literal: true

# Guards the contract that both uploader entry points -- CamaleonCms::RuntimeUploaderConcern
# (controllers) and CamaleonCms::UploaderHelper (views, ActiveJobs, standalone objects) --
# resolve to one shared implementation, so an upload fix cannot land in one and not the other.
# rubocop:disable RSpec/DescribeClass -- the subject is the contract across three shared
# modules and two entry points, not any single one of them.
RSpec.describe 'uploader implementation parity' do
  concern = CamaleonCms::RuntimeUploaderConcern
  helper = CamaleonCms::UploaderHelper

  shared_public = {
    CamaleonCms::UploaderPipeline => %i[upload_file cama_tmp_upload],
    CamaleonCms::UploaderImageProcessing => %i[cama_uploader_generate_thumbnail cama_crop_image
                                               cama_resize_and_crop cama_resize_upload],
    CamaleonCms::UploaderSupport => %i[cama_uploader uploader_verify_name cama_file_path_to_url
                                       cama_url_to_file_path slugify slugify_folder]
  }
  shared_private = {
    CamaleonCms::UploaderPipeline => %i[cama_download_remote_file validate_file_format_or_error
                                        cama_stage_data_uri cama_size_limit_error],
    CamaleonCms::UploaderImageProcessing => %i[cama_crop_offsets_by_gravity clamp_to_image_dimension]
  }
  all_shared = (shared_public.values + shared_private.values).flatten

  describe 'single definition site' do
    it 'defines no shared uploader method directly on either entry point' do
      own = lambda do |mod|
        (mod.instance_methods(false) + mod.private_instance_methods(false)) & all_shared
      end

      expect(own.call(concern)).to be_empty
      expect(own.call(helper)).to be_empty
    end

    shared_public.merge(shared_private) { |_k, a, b| a + b }.each do |owner, names|
      names.each do |name|
        it "resolves ##{name} to #{owner} from both entry points" do
          expect(concern.instance_method(name).owner).to eq(owner)
          expect(helper.instance_method(name).owner).to eq(owner)
        end
      end
    end
  end

  describe 'entry-point-specific code' do
    it 'keeps cama_upload_url_error on the controller concern only' do
      expect(concern.private_instance_methods(false)).to include(:cama_upload_url_error)
      expect(helper.instance_methods + helper.private_instance_methods).not_to include(:cama_upload_url_error)
    end

    it 'keeps the t and human_size seam overrides on the helper only' do
      seam = %i[cama_uploader_t cama_uploader_human_size]

      expect(helper.instance_methods(false) & seam).to match_array(seam)
      expect(concern.instance_methods(false) & seam).to be_empty
      seam.each { |name| expect(concern.instance_method(name).owner).to eq(CamaleonCms::UploaderPipeline) }
    end

    it 'overrides cama_uploader_ct on both entry points so each can run its own translation hook' do
      # The helper always routes through ct; the concern routes through ct only when its host
      # responds to it (the media controllers), falling back to the pipeline I18n default.
      expect(helper.instance_method(:cama_uploader_ct).owner).to eq(CamaleonCms::UploaderHelper)
      expect(concern.instance_method(:cama_uploader_ct).owner).to eq(CamaleonCms::RuntimeUploaderConcern)
    end
  end

  describe 'message seam defaults' do
    # The concern's context has no `ct`, so the pipeline defaults must render from I18n
    # unaided. Exercised on a bare object to prove no controller machinery is needed.
    let(:concern_obj) { Class.new { include CamaleonCms::RuntimeUploaderConcern }.new }
    let(:helper_obj) do
      Class.new do
        include CamaleonCms::UploaderHelper
        def hooks_run(_key, _args = nil); end
      end.new
    end

    it 'renders the size-limit error without ct being defined' do
      expect(concern_obj.respond_to?(:ct, true)).to be(false)

      err = concern_obj.send(:cama_size_limit_error, 2.megabytes, 1.megabyte)

      expect(err[:error]).to include(I18n.t('camaleon_cms.common.file_size_exceeded',
                                            default: 'File size exceeded'))
    end

    it 'reports the same human-readable limit through both entry points' do
      concern_err = concern_obj.send(:cama_size_limit_error, 2.megabytes, 1.megabyte)
      helper_err = helper_obj.send(:cama_size_limit_error, 2.megabytes, 1.megabyte)

      expect(concern_err[:error]).to include('1 MB')
      expect(helper_err[:error]).to include('1 MB')
    end

    it 'returns nil when the size is within the limit, through both entry points' do
      expect(concern_obj.send(:cama_size_limit_error, 1.megabyte, 2.megabytes)).to be_nil
      expect(helper_obj.send(:cama_size_limit_error, 1.megabyte, 2.megabytes)).to be_nil
    end
  end

  describe 'visibility parity' do
    let(:concern_obj) { Class.new { include CamaleonCms::RuntimeStateConcern }.new }
    let(:helper_obj) { Class.new { include CamaleonCms::UploaderHelper }.new }

    it 'exposes the same public uploader methods through both entry points' do
      shared_public.values.flatten.each do |name|
        expect(concern_obj).to respond_to(name)
        expect(helper_obj).to respond_to(name)
      end
    end

    it 'keeps the previously private methods private through both entry points' do
      shared_private.values.flatten.each do |name|
        expect(concern_obj).not_to respond_to(name)
        expect(helper_obj).not_to respond_to(name)
        expect(concern_obj.respond_to?(name, true)).to be(true)
        expect(helper_obj.respond_to?(name, true)).to be(true)
      end
    end
  end
end

# rubocop:enable RSpec/DescribeClass
