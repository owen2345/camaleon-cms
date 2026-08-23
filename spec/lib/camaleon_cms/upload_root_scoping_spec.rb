# frozen_string_literal: true

RSpec.describe CamaleonCms::UploaderPathSecurity do
  let(:subject_class) { Class.new { include CamaleonCms::UploaderPathSecurity }.new }

  describe '#cama_canonical_upload_path default roots' do
    it 'accepts a path under the public root' do
      path = Rails.public_path.join('tmp', 'roots-default.txt').to_s

      expect(subject_class.cama_canonical_upload_path(path)).to eq(path)
    end

    it 'rejects an absolute system path' do
      expect(subject_class.cama_canonical_upload_path('/etc/passwd')).to be_nil
    end

    it 'rejects traversal that escapes the public root' do
      escape = Rails.public_path.join('..', '..', 'etc', 'passwd').to_s

      expect(subject_class.cama_canonical_upload_path(escape)).to be_nil
    end

    it 'rejects a path under Rails.root that is outside the default roots' do
      expect(subject_class.cama_canonical_upload_path(Rails.root.join('storage/x.png').to_s)).to be_nil
    end
  end

  describe '#cama_canonical_upload_path with caller-supplied roots' do
    let(:extra_root) { Rails.root.join('storage').to_s }

    it 'accepts a path inside an explicitly allowed root' do
      path = File.join(extra_root, 'import', 'photo.png')

      expect(subject_class.cama_canonical_upload_path(path, extra_roots: [extra_root])).to eq(path)
    end

    it 'still rejects traversal out of an explicitly allowed root' do
      escape = File.join(extra_root, '..', '..', 'etc', 'passwd')

      expect(subject_class.cama_canonical_upload_path(escape, extra_roots: [extra_root])).to be_nil
    end

    it 'does not leak the extension to a later call' do
      path = File.join(extra_root, 'import', 'photo.png')
      subject_class.cama_canonical_upload_path(path, extra_roots: [extra_root])

      expect(subject_class.cama_canonical_upload_path(path)).to be_nil
    end

    it 'ignores blank entries in the extra roots' do
      expect(subject_class.cama_canonical_upload_path('/etc/passwd', extra_roots: [nil, ''])).to be_nil
    end
  end

  describe 'private-media root' do
    let(:private_path) { Rails.root.join(CamaleonCmsUploader::PRIVATE_DIRECTORY, 'doc.pdf').to_s }

    it 'rejects a private-media path when private mode is not active' do
      expect(subject_class.cama_canonical_upload_path(private_path)).to be_nil
    end

    it 'accepts a private-media path while private mode is active' do
      private_host = Class.new do
        include CamaleonCms::UploaderPathSecurity

        def cama_uploader
          Struct.new(:private).new(true).tap do |u|
            # Name mirrors the real uploader API this stands in for.
            def u.is_private_uploader? = true # rubocop:disable Naming/PredicatePrefix
          end
        end
      end.new

      expect(private_host.cama_canonical_upload_path(private_path)).to eq(private_path)
    end
  end

  # `cama_source_already_public?` used to exempt sources under the public root from re-scanning.
  # It is gone: whether an upload is scanned is now an authorization question, answered by
  # `cama_trusted_for_unfiltered_upload?`, not by where the source file happens to sit.
  describe 'the withdrawn public-source exemption' do
    it 'no longer exists as a predicate' do
      expect(subject_class).not_to respond_to(:cama_source_already_public?)
    end
  end
end
