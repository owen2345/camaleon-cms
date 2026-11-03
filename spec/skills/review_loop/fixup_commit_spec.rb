# frozen_string_literal: true

# The fixup commit of a failure fix from a temporary index (docs/ai/workflows.md, Phase 3).
RSpec.describe 'scripts/fixup-commit.sh' do
  include ReviewLoopScripts

  before do
    @first = init_repo(dir, 'a.txt' => "a1\na2\na3\n", 'b.txt' => "b1\nb2\nb3\n")
    @second = commit(dir, { 'c.txt' => "c\n" }, 'second')
    # The uncommitted fix changes a.txt and adds new.txt. Its tree is <before>.
    write_files(dir, 'a.txt' => "a1\nfix\na3\n", 'new.txt' => "new\n")
    @before = checkout_tree(dir)
  end

  def fixup(after, before: @before, env: {})
    run_script('fixup-commit.sh', dir, before, after, @first, env: env)
  end

  # Writes the failure fix, to b.txt unless the files say otherwise, and returns its tree, <after>.
  def failure_fix(files = { 'b.txt' => "b1\nfailure fix\nb3\n" })
    write_files(dir, files)
    checkout_tree(dir)
  end

  it 'commits the difference of the trees as a fixup commit and leaves the checkout as it is' do
    result = fixup(failure_fix)
    expect(result.status).to eq(0), result.err
    expect(git(dir, 'log', '-1', '--format=%s')).to eq("fixup! #{@first}")
    expect(git(dir, 'diff', '--name-only', @second, 'HEAD')).to eq('b.txt')
    expect(git(dir, 'show', 'HEAD:b.txt')).to eq("b1\nfailure fix\nb3")
    expect(File.read(File.join(dir, 'a.txt'))).to eq("a1\nfix\na3\n")
    expect(git(dir, 'status', '--porcelain', '--', 'a.txt',
               'new.txt').lines(chomp: true)).to eq([' M a.txt', '?? new.txt'])
    expect(git(dir, 'diff', 'HEAD', '--', 'b.txt')).to eq('')
  end

  it 'leaves a staged fix staged' do
    git(dir, 'add', '-A')
    expect(fixup(failure_fix).status).to eq(0)
    expect(git(dir, 'status', '--porcelain').lines(chomp: true)).to eq(['M  a.txt', 'A  new.txt'])
  end

  it 'leaves the checkout clean when the failure fix is the only fix' do
    git(dir, 'checkout', '--', 'a.txt')
    File.delete(File.join(dir, 'new.txt'))
    expect(fixup(failure_fix, before: git(dir, 'rev-parse', 'HEAD')).status).to eq(0)
    expect(git(dir, 'status', '--porcelain')).to eq('')
  end

  it 'resets the old path of a renamed file too' do
    File.rename(File.join(dir, 'b.txt'), File.join(dir, 'moved.txt'))
    expect(fixup(checkout_tree(dir)).status).to eq(0)
    expect(git(dir, 'status', '--porcelain', '--', 'b.txt', 'moved.txt')).to eq('')
  end

  it 'resets a path that git could read as a pathspec' do
    expect(fixup(failure_fix(':colon.txt' => "c\n")).status).to eq(0)
    expect(git(dir, 'status', '--porcelain').lines(chomp: true)).to eq([' M a.txt', '?? new.txt'])
  end

  it 'stages a path that both fixes changed' do
    expect(fixup(failure_fix('a.txt' => "a1\nfix\na3\na4\n")).status).to eq(0)
    expect(git(dir, 'status', '--porcelain', '--', 'a.txt')).to eq('M  a.txt')
  end

  it 'keeps a staged fix staged on a path that both fixes changed' do
    git(dir, 'add', '-A')
    expect(fixup(failure_fix('a.txt' => "a1\nfix\na3\na4\n")).status).to eq(0)
    expect(git(dir, 'status', '--porcelain', '--', 'a.txt')).to eq('M  a.txt')
  end

  it 'commits a failure fix whose patch context holds a line of the uncommitted fix' do
    # The patch of a4 carries line 2 as context, which HEAD does not have: only a 3-way apply merges it.
    result = fixup(failure_fix('a.txt' => "a1\nfix\na3\na4\n"))
    expect(result.status).to eq(0), result.err
    expect(git(dir, 'show', 'HEAD:a.txt')).to eq("a1\na2\na3\na4")
  end

  it 'commits under a config of the user that changes the diff output or the apply' do
    # The failure fix adds a trailing blank, which apply.whitespace=fix would strip.
    keys = { 'diff.noprefix' => 'true', 'color.diff' => 'always', 'diff.external' => 'true', 'diff.context' => '0',
             'apply.whitespace' => 'fix' }
    config = { 'GIT_CONFIG_COUNT' => keys.size.to_s }
    keys.each_with_index { |(k, v), i| config.merge!("GIT_CONFIG_KEY_#{i}" => k, "GIT_CONFIG_VALUE_#{i}" => v) }
    result = fixup(failure_fix('b.txt' => "b1\nfailure fix \nb3\n"), env: config)
    expect(result.status).to eq(0), result.err
    expect(git(dir, 'show', 'HEAD:b.txt')).to eq("b1\nfailure fix \nb3")
  end

  it 'commits a failure fix that adds a binary file' do
    result = fixup(failure_fix('img.bin' => "\x00\xFF\n"))
    expect(result.status).to eq(0), result.err
    expect(git(dir, 'diff', '--name-only', @second, 'HEAD')).to eq('img.bin')
  end

  it 'exits with 1 when the failure fix touches the lines of the uncommitted fix' do
    expect(fixup(failure_fix('a.txt' => "a1\nfailure fix\na3\n")).status).to eq(1)
    expect(git(dir, 'rev-parse', 'HEAD')).to eq(@second)
  end

  it 'exits with 1 when the failure fix changes a file that the uncommitted fix adds' do
    expect(fixup(failure_fix('new.txt' => "new\nfailure fix\n")).status).to eq(1)
  end

  it 'exits with the code of the apply for an empty difference' do
    expect(fixup(@before).status).to eq(128)
  end

  it 'exits with 3 and puts the index back when the commit fails' do
    write_executable('.git/hooks/pre-commit', "#!/bin/sh\nexit 1\n")
    expect(fixup(failure_fix).status).to eq(3)
    expect(git(dir, 'rev-parse', 'HEAD')).to eq(@second)
    expect(git(dir, 'status', '--porcelain', '--', 'b.txt')).to eq(' M b.txt')
  end

  it 'exits with 3 and makes no fixup commit when the reset of the index fails' do
    after = failure_fix
    FileUtils.touch(File.join(dir, '.git/index.lock'))
    expect(fixup(after).status).to eq(3)
    expect(git(dir, 'rev-parse', 'HEAD')).to eq(@second)
  end

  it 'exits with 2 without four arguments' do
    expect(run_script('fixup-commit.sh', dir, @before, @before).status).to eq(2)
  end
end
