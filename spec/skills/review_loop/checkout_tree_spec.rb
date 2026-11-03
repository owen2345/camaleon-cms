# frozen_string_literal: true

# The tree of a checkout with every change staged, from a temporary index (procedure.md, Checks).
RSpec.describe 'scripts/checkout-tree.sh' do
  include ReviewLoopScripts

  before { init_repo(dir, 'a.txt' => "a\n", 'b.txt' => "b\n") }

  it 'prints the tree of HEAD for a clean checkout' do
    result = run_script('checkout-tree.sh', dir)
    expect(result.out).to eq("#{git(dir, 'rev-parse', 'HEAD^{tree}')}\n")
    expect(result.status).to eq(0)
  end

  it 'prints the tree with the new, changed and deleted files, and leaves the index as it is' do
    write_files(dir, 'a.txt' => "changed\n", 'new.txt' => "new\n")
    File.unlink(File.join(dir, 'b.txt'))
    result = run_script('checkout-tree.sh', dir)
    expect(result.status).to eq(0)
    expect(git(dir, 'status', '--porcelain').lines(chomp: true)).to eq([' M a.txt', ' D b.txt', '?? new.txt'])
    git(dir, 'add', '-A')
    expect(result.out).to eq("#{git(dir, 'write-tree')}\n")
  end

  it 'prints the tree of the work tree when the index holds another staged content' do
    # A racy entry: the file keeps the size and the mtime of its index entry, and the index file has that mtime
    # too. With core.trustctime off, git ignores the ctime. Only a copy of the index that keeps its mtime reads
    # the file.
    path = File.join(dir, 'a.txt')
    git(dir, 'config', 'core.trustctime', 'false')
    write_files(dir, 'a.txt' => "staged\n")
    old = 10.seconds.ago.to_time
    File.utime(old, old, path)
    git(dir, 'add', 'a.txt')
    write_files(dir, 'a.txt' => "worked\n")
    File.utime(old, old, path)
    File.utime(old, old, File.join(dir, '.git/index'))
    result = run_script('checkout-tree.sh', dir)
    expect(result.status).to eq(0)
    expect(git(dir, 'ls-tree', result.out.chomp, 'a.txt')).to include(git(dir, 'hash-object', File.join(dir, 'a.txt')))
    expect(git(dir, 'diff', '--cached', '--name-only')).to eq('a.txt')
  end

  it 'fails outside a repository' do
    Dir.mktmpdir('not-a-repo') do |dir|
      expect(run_script('checkout-tree.sh', dir).status).not_to eq(0)
    end
  end

  it 'exits with 2 without a checkout' do
    expect(run_script('checkout-tree.sh').status).to eq(2)
  end
end
