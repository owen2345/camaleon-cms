# frozen_string_literal: true

RSpec.describe CamaleonCms::UploaderPathSecurity do
  let(:subject_class) { Class.new { include CamaleonCms::UploaderPathSecurity }.new }
  let(:root) { Rails.public_path.join('tmp', 'purge_spec').to_s }

  before { FileUtils.mkdir_p(root) }

  after { FileUtils.rm_rf(root) }

  describe '#cama_purge_staged_file' do
    it 'removes a file inside the staging root' do
      target = File.join(root, 'staged.txt')
      File.write(target, 'x')

      expect(subject_class.cama_purge_staged_file(target, root)).to be(true)
      expect(File.exist?(target)).to be(false)
    end

    it 'does not delete a file that canonicalizes outside the staging root' do
      outside = Rails.public_path.join('tmp', 'outside_purge_spec.txt').to_s
      File.write(outside, 'keep me')

      escape = File.join(root, '..', 'outside_purge_spec.txt')
      expect(subject_class.cama_purge_staged_file(escape, root)).to be(false)
      expect(File.exist?(outside)).to be(true)
    ensure
      FileUtils.rm_f(outside)
    end

    it 'refuses a blank path' do
      expect(subject_class.cama_purge_staged_file('', root)).to be(false)
      expect(subject_class.cama_purge_staged_file(nil, root)).to be(false)
    end

    it 'refuses a blank root' do
      expect(subject_class.cama_purge_staged_file(File.join(root, 'x.txt'), nil)).to be(false)
    end

    it 'returns false rather than raising on a hostile path' do
      expect(subject_class.cama_purge_staged_file("bad\0path", root)).to be(false)
    end
  end

  describe '#cama_base64_decoded_size' do
    it 'estimates the decoded size within two bytes of the real value' do
      %w[a ab abc abcd abcde].each do |sample|
        encoded = Base64.strict_encode64(sample)
        estimate = subject_class.cama_base64_decoded_size(encoded)
        expect(estimate).to be >= sample.bytesize
        expect(estimate - sample.bytesize).to be <= 2
      end
    end

    it 'never underestimates, so an oversized payload cannot slip through' do
      payload = 'A' * 10_000
      encoded = Base64.strict_encode64(payload)
      expect(subject_class.cama_base64_decoded_size(encoded)).to be >= payload.bytesize
    end

    it 'treats nil as zero' do
      expect(subject_class.cama_base64_decoded_size(nil)).to eq(0)
    end
  end
end
