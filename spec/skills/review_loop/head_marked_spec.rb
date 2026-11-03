# frozen_string_literal: true

# The skip marker test of ci.md: a bracket marker in the message, or a skip-checks trailer.
RSpec.describe 'scripts/head-marked.sh' do
  include ReviewLoopScripts

  before { init_repo(dir) }

  # Commits the message as it is and checks that git stored it. The script runs under UTF8_LOCALE, so an
  # example with a byte that is not UTF-8 fails on macOS when the script drops its LC_ALL=C.
  def marked(message, *options)
    sha = commit(dir, { 'f.txt' => "#{rand}\n" }, message, '--cleanup=verbatim', *options)
    expect(git(dir, 'cat-file', 'commit', sha).b).to end_with(message.b.chomp)
    run_script('head-marked.sh', dir, sha, env: ReviewLoopScripts::UTF8_LOCALE).status
  end

  it 'exits with 1 for a plain message' do
    expect(marked("Subject\n\nA sentence about skip-checks.")).to eq(1)
  end

  it 'exits with 0 for each bracket marker that docs/ai/workflows.md Phase 3 lists' do
    markers = CAMALEON_CMS_ROOT.join('docs/ai/workflows.md').read.scan(/^- `(\[[a-z ]+\])`$/).flatten
    expect(markers.size).to eq(5)
    markers.each { |marker| expect(marked("Subject\n\n#{marker}")).to eq(0) }
  end

  it 'exits with 0 for a bracket marker in the subject' do
    expect(marked('Subject [ci skip]')).to eq(0)
  end

  it 'exits with 0 for a skip-checks trailer after two empty lines' do
    expect(marked("Subject\n\n\nskip-checks: true")).to eq(0)
    expect(marked("Subject\n\n\nskip-checks:true")).to eq(0)
  end

  it 'exits with 1 for a skip-checks line anywhere else' do
    expect(marked("Subject\n\nskip-checks: true")).to eq(1)
    expect(marked("Subject\n\n\nskip-checks: true\n\nMore.")).to eq(1)
  end

  it 'exits with 1 for a skip-checks trailer that empty lines follow' do
    expect(marked("Subject\n\n\nskip-checks: true\n\n")).to eq(1)
  end

  context 'with a message that is not UTF-8' do
    # Under its UTF-8 default, git rewrites a byte that is not UTF-8. Under another commit encoding it keeps it.
    before { git(dir, 'config', 'i18n.commitEncoding', 'ISO-8859-1') }

    it 'exits with 0 for a bracket marker' do
      expect(marked("Fix caf\xE9 [skip ci]")).to eq(0)
    end

    it 'exits with 1 for a skip-checks trailer that a stray byte follows' do
      expect(marked("Subject\n\n\nskip-checks: true\xFF")).to eq(1)
    end
  end

  it 'exits with 1 for an empty message whose author name holds a marker' do
    expect(marked('', '--allow-empty-message', '--author=[skip ci] <spec@example.com>')).to eq(1)
  end

  it 'exits with 2 for a commit that git cannot read' do
    expect(run_script('head-marked.sh', dir, 'f' * 40).status).to eq(2)
  end

  it 'exits with 2 with one argument' do
    expect(run_script('head-marked.sh', dir).status).to eq(2)
  end
end
