# frozen_string_literal: true

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

  describe '#search_new_key (bucket collision without a cache row)' do
    let(:existing_object) { instance_double(Aws::S3::Object, exists?: true) }
    let(:free_object) { instance_double(Aws::S3::Object, exists?: false) }

    it 'renames the key when the bucket already holds an uncached object at it' do
      allow(bucket).to receive(:object).with('notes.txt').and_return(existing_object)
      allow(bucket).to receive(:object).with('notes_1.txt').and_return(free_object)

      expect(uploader.search_new_key('/notes.txt')).to eq('/notes_1.txt')
    end

    it 'treats a failing existence check as absent (pre-existing cache-only behavior)' do
      failing = instance_double(Aws::S3::Object)
      allow(failing).to receive(:exists?).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'denied'))
      allow(bucket).to receive(:object).with('notes.txt').and_return(failing)

      expect(uploader.search_new_key('/notes.txt')).to eq('/notes.txt')
    end
  end

  describe 'deletes with no cache row (missing row tolerance)' do
    let(:s3_object_collection) { instance_double(Aws::S3::ObjectSummary::Collection, delete: true) }
    let(:s3_object) { instance_double(Aws::S3::Object, delete: true) }

    it '#delete_folder does not raise when the folder has no cache row' do
      allow(bucket).to receive(:objects).with(prefix: 'ghost/').and_return(s3_object_collection)

      expect { uploader.delete_folder('/ghost') }.not_to raise_error
    end

    it '#delete_file does not raise when the file has no cache row' do
      allow(bucket).to receive(:object).with('ghost.txt').and_return(s3_object)

      expect { uploader.delete_file('/ghost.txt') }.not_to raise_error
    end
  end

  describe '#repair_private_acls!' do
    # Security (audit 2026-08-11 M5 follow-up): objects uploaded before the private-ACL fix stayed
    # world-readable; the sweep re-applies the owner-only ACL under the private prefix, including a
    # configured inner_folder root.
    let(:object_acl) { instance_double(Aws::S3::ObjectAcl) }
    let(:s3_object) { instance_double(Aws::S3::ObjectSummary, acl: object_acl) }

    it 'sweeps objects under the default private prefix back to an owner-only ACL' do
      allow(bucket).to receive(:objects).with(prefix: 'private/').and_return([s3_object, s3_object])
      expect(object_acl).to receive(:put).with(acl: 'private').twice

      expect(uploader.repair_private_acls!).to eq(2)
    end

    context 'with a configured inner_folder' do
      let(:uploader) do
        described_class.new({ current_site: current_site, aws_settings: { 'inner_folder' => 'myfolder' } },
                            hook_instance)
      end

      it 'sweeps under <inner_folder>/private/' do
        allow(bucket).to receive(:objects).with(prefix: 'myfolder/private/').and_return([])

        expect(uploader.repair_private_acls!).to eq(0)
      end
    end
  end

  describe '#file_parse thumb naming for an uppercase .SVG source' do
    let(:s3_file) do
      instance_double(Aws::S3::Object, key: 'media/1/logo.SVG', size: 123.4, last_modified: Time.zone.now,
                                       public_url: 'https://s3.example.com/media/1/logo.SVG')
    end

    it 'computes the .jpg thumb url (case-insensitive svg-to-jpg rename)' do
      expect(uploader.file_parse(s3_file)['thumb']).to end_with('/thumb/logo-svg.jpg')
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

      # Security (audit 2026-08-11 M5): a private-mode upload must not be world-readable. On master it
      # was stored with acl: 'public-read' regardless of mode, so a guessed s3://bucket/private/<name>
      # URL bypassed the download_private_file access gate.
      context 'when the uploader is in private mode' do
        let(:uploader) do
          described_class.new({ current_site: current_site, aws_settings: {}, private: true }, hook_instance)
        end

        it 'stores the object with a private ACL, not public-read' do
          file_path = "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png"

          expect(s3_file).to receive(:upload_file).with(file_path, { acl: 'private' })

          uploader.add_file(file_path, 'safe/test.png')
        end
      end
    end
  end
end
