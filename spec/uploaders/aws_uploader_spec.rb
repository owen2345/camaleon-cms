# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCmsAwsUploader do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:hook_instance) { instance_double('UploaderHookInstance', hooks_run: nil) } # rubocop:disable RSpec/VerifiedDoubleReference
  let(:uploader) { described_class.new({ current_site: current_site, aws_settings: {} }, hook_instance) }
  let(:bucket) { instance_double(Aws::S3::Bucket) }

  before { allow(uploader).to receive(:bucket).and_return(bucket) }

  context 'with an invalid path containing path traversal characters' do
    describe '#add_file' do
      it 'returns an error' do
        expect(bucket).not_to receive(:object)

        expect(uploader.add_file('/tmp/test.png', '../tmp/test.png')).to eql(error: 'Invalid file path')
      end
    end

    describe '#delete_folder' do
      it 'returns an error' do
        expect(bucket).not_to receive(:objects)

        expect(uploader.delete_folder('../tmp')).to eql(error: 'Invalid folder path')
      end
    end

    describe '#delete_file' do
      it 'returns an error' do
        expect(bucket).not_to receive(:object)
        expect(hook_instance).not_to receive(:hooks_run)

        expect(uploader.delete_file('../tmp/test.png')).to eql(error: 'Invalid file path')
      end
    end
  end

  context 'with an invalid URI-like path' do
    describe '#add_file' do
      it 'returns an error' do
        expect(bucket).not_to receive(:object)

        expect(uploader.add_file('/tmp/test.png', 'file:///tmp/test.png')).to eql(error: 'Invalid file path')
      end
    end

    describe '#delete_folder' do
      it 'returns an error' do
        expect(bucket).not_to receive(:objects)

        expect(uploader.delete_folder('s3://bucket/folder')).to eql(error: 'Invalid folder path')
      end
    end

    describe '#delete_file' do
      it 'returns an error' do
        expect(bucket).not_to receive(:object)
        expect(hook_instance).not_to receive(:hooks_run)

        expect(uploader.delete_file('https://example.com/file.txt')).to eql(error: 'Invalid file path')
      end
    end
  end

  context 'with a valid file path' do
    describe '#add_file' do
      let(:s3_file) { instance_double(Aws::S3::Object) }
      let(:parsed_file) do
        {
          'name' => 'test.png',
          'folder_path' => '/safe',
          'url' => 'https://cdn.example.com/safe/test.png',
          'is_folder' => false,
          'file_size' => 123.45,
          'thumb' => '/safe/thumb/test-png.png',
          'file_type' => 'image',
          'created_at' => '2026-03-09T00:00:00Z',
          'dimension' => '100x100',
          'key' => '/safe/test.png'
        }
      end

      before do
        allow(bucket).to receive(:object).and_return(s3_file)
        allow(s3_file).to receive(:upload_file).and_return(true)
        allow(uploader).to receive(:search_new_key).and_return('/safe/test.png')
        allow(uploader).to receive(:file_parse).with(s3_file).and_return(parsed_file)
        allow(uploader).to receive(:cache_item).with(parsed_file).and_return(parsed_file)
      end

      it 'uploads the file and returns cached metadata' do
        file_path = "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png"
        expect(hook_instance).to receive(:hooks_run).with(
          'uploader_aws_before_upload',
          hash_including(
            file: file_path, key: '/safe/test.png', args: hash_including(same_name: false, is_thumb: false)
          )
        )

        expect(bucket).to receive(:object).with('safe/test.png')
        expect(s3_file).to receive(:upload_file).with(file_path, { acl: 'public-read' })

        result = uploader.add_file(file_path, 'safe/test.png')

        expect(result).to eql(parsed_file)
      end
    end
  end
end
