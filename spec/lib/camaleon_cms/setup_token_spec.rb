# frozen_string_literal: true

# File-based token semantics for the installer gate: created with 0600 permissions from the first
# byte, adopted (not clobbered) when losing a creation race, and removed once setup completes.
# See openspec/specs/installer-access-control/spec.md.
RSpec.describe CamaleonCms::SetupToken do
  around do |example|
    previous = ENV.delete('CAMALEON_SETUP_TOKEN')
    FileUtils.rm_f(described_class.file_path)
    example.run
  ensure
    ENV['CAMALEON_SETUP_TOKEN'] = previous if previous
    FileUtils.rm_f(described_class.file_path)
  end

  it 'creates the token file with 0600 permissions from the first byte' do
    token = described_class.value

    expect(token).to match(/\A\h{64}\z/)
    expect(File.stat(described_class.file_path).mode & 0o777).to eq(0o600)
    expect(File.read(described_class.file_path)).to eq(token)
  end

  it 'adopts the already-written token when it loses the creation race' do
    File.write(described_class.file_path, 'winner-token')
    # Simulate the race: the exist? check misses the file another request is writing concurrently,
    # so the EXCL open raises EEXIST and the loser must converge on the winner's token.
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(described_class.file_path).and_return(false, true)

    expect(described_class.value).to eq('winner-token')
    expect(File.read(described_class.file_path)).to eq('winner-token')
  end

  it 'removes the generated file on clear! so the token cannot be replayed' do
    described_class.value
    described_class.clear!

    expect(File.exist?(described_class.file_path)).to be(false)
  end
end
