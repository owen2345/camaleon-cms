# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Runs a script of the review-loop skill, under .claude/skills/review-loop/scripts, in a child process. It also
# gives the examples a scratch directory, a scratch git repository and the fake gh and pgrep under
# spec/support/review_loop/fakes.
module ReviewLoopScripts
  # Each example gets a scratch directory, dir, which the hook removes after it. Its path holds a space, so a
  # shell body that does not quote a path fails here, as it does under such a TMPDIR.
  def self.included(group)
    group.around do |example|
      Dir.mktmpdir('review-loop') do |tmp|
        @dir = File.join(tmp, 'scratch dir')
        Dir.mkdir(@dir)
        example.run
      end
    end
  end

  SCRIPTS = CAMALEON_CMS_ROOT.join('.claude/skills/review-loop/scripts')
  FAKES = CAMALEON_CMS_ROOT.join('spec/support/review_loop/fakes')
  # The git environment of the examples: no user or system config, and a fixed author.
  GIT_ENV = {
    'GIT_CONFIG_GLOBAL' => '/dev/null', 'GIT_CONFIG_NOSYSTEM' => '1',
    'GIT_AUTHOR_NAME' => 'Spec', 'GIT_AUTHOR_EMAIL' => 'spec@example.com',
    'GIT_COMMITTER_NAME' => 'Spec', 'GIT_COMMITTER_EMAIL' => 'spec@example.com'
  }.freeze
  # bin/rspec sets RUBYOPT to load bundler/setup, which a script does not need: the child loads no gem at all.
  # A child never sleeps between two tries: REVIEW_LOOP_SLEEP tells the scripts that wait or poll. The knob, not
  # a fake sleep on PATH, keeps that test hook visible (intended).
  CHILD_ENV = GIT_ENV.merge('RUBYOPT' => '--disable-gems', 'RUBYLIB' => nil, 'REVIEW_LOOP_SLEEP' => '0').freeze
  # A locale under which a plain read of a file is not UTF-8.
  C_LOCALE = { 'LC_ALL' => 'C', 'LANG' => 'C' }.freeze
  # A UTF-8 locale, under which the awk, grep and tr of macOS refuse an invalid byte unless the script sets
  # LC_ALL=C. The GNU tools of the CI runner copy the byte, so an example that passes it pins the guard on macOS.
  UTF8_LOCALE = { 'LC_ALL' => 'C.UTF-8', 'LANG' => 'C.UTF-8' }.freeze

  Result = Struct.new(:out, :err, :status) do
    def lines
      out.lines(chomp: true)
    end
  end

  # The scratch directory of the example.
  attr_reader :dir

  # Skips the example when jq, which the fake gh needs, is not on PATH.
  def skip_without_jq
    skip 'jq is not on PATH' unless system('jq', '--version', out: File::NULL, err: File::NULL)
  end

  # A sentence of count words: the first word, then w2 to w<count>.
  def words(count, first: 'W')
    ([first] + (2..count).map { |i| "w#{i}" }).join(' ')
  end

  # A sentence of 26 words with two accented words, which a byte read splits into shorter sentences.
  def accented_sentence
    "#{words(12)} résumé Été #{words(12, first: 'x15')}."
  end

  # The ledger of the example, under dir. write_ledger writes the String to it and returns the path.
  def ledger_path
    File.join(dir, 'ledger.md')
  end

  def write_ledger(text)
    File.write(ledger_path, text)
    ledger_path
  end

  # The tree of the repository with every change staged (checkout-tree.sh).
  def checkout_tree(repo)
    run_script('checkout-tree.sh', repo).out.chomp
  end

  # Runs the script with the arguments. stdin is the standard input of the script, and env adds to its
  # environment. Returns its output, its error output and its exit code.
  def run_script(name, *args, stdin: '', env: {})
    out, err, status = Open3.capture3(*script_command(name, *args, env: env), stdin_data: stdin)
    Result.new(out, err, status.exitstatus)
  end

  # Starts the script as run_script does. It yields the input, the output with the error output, and the
  # thread, so an example can read the output while the script runs. Returns the value of the block.
  def spawn_script(name, *args, env: {}, &block)
    Open3.popen2e(*script_command(name, *args, env: env), &block)
  end

  # The environment and the command line of the script with the arguments. The pair of paths keeps a path with
  # a space whole when the script gets no argument.
  def script_command(name, *args, env: {})
    script = SCRIPTS.join(name).to_s
    [CHILD_ENV.merge(env), [script, script], *args]
  end

  # Runs git in the repository and returns its output without the last newline. Raises when git fails.
  def git(repo, *args)
    out, err, status = Open3.capture3(GIT_ENV, 'git', '-C', repo.to_s, *args)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?

    out.chomp
  end

  # Makes a git repository in dir, with one commit of the files, a Hash of path to content. Returns the SHA.
  def init_repo(dir, files = { 'a.txt' => "a\n" })
    git(dir, '-c', 'init.defaultBranch=main', 'init', '-q')
    commit(dir, files, 'first')
  end

  # Writes the files, stages every change and commits with the message. Returns the SHA.
  def commit(dir, files, message, *options)
    write_files(dir, files)
    git(dir, 'add', '-A')
    git(dir, 'commit', '-q', *options, '-m', message)
    git(dir, 'rev-parse', 'HEAD')
  end

  def write_files(dir, files)
    files.each do |path, content|
      full = File.join(dir, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
    end
  end

  # The environment that puts the fake gh and pgrep first on PATH. The answers, one per call, go in a file of
  # dir. A fake repeats the last answer, and writes the arguments of each call to the calls file of dir.
  def fake_env(dir, answers)
    answers_file = File.join(dir, 'answers')
    File.write(answers_file, answers.map { |a| "#{a}\n" }.join)
    { 'PATH' => path_with(FAKES), 'FAKE_ANSWERS' => answers_file, 'FAKE_CALLS' => File.join(dir, 'calls') }
  end

  # Writes an executable file at the path under dir.
  def write_executable(path, body)
    write_files(dir, path => body)
    File.chmod(0o755, File.join(dir, path))
  end

  # The environment that puts a scratch executable, bin/<name> under dir with the body, first on PATH. A body
  # that records a call writes it as answer.sh does: printf '%s\0' "$*" >> "$FAKE_CALLS". A body that records
  # the time of a call uses the STAMP line, for stamp_gaps. FAKES names the folder of the fakes, for a body that
  # runs one of them.
  def shim_env(name, body)
    write_executable(File.join('bin', name), body)
    { 'PATH' => path_with(File.join(dir, 'bin')), 'FAKE_CALLS' => File.join(dir, 'calls'),
      'STAMPS' => File.join(dir, 'stamps'), 'FAKES' => FAKES.to_s }
  end

  # A shell line that appends the time of the call, in seconds, to the file that STAMPS names.
  STAMP = %q(perl -MTime::HiRes=time -e 'print time, "\n"' >> "$STAMPS")

  # The REVIEW_LOOP_SLEEP of an example that checks the sleep of a script, in seconds.
  SLEEP = '0.3'

  # The seconds between two calls that STAMP recorded, one per gap.
  def stamp_gaps
    File.readlines(File.join(dir, 'stamps')).map(&:to_f).each_cons(2).map { |a, b| b - a }
  end

  # Checks that STAMP recorded the calls, with at least SLEEP seconds between two of them.
  def expect_sleeps_between(calls)
    expect(stamp_gaps.size).to eq(calls - 1)
    expect(stamp_gaps).to all(be >= SLEEP.to_f)
  end

  # A PATH that starts with the folder.
  def path_with(folder)
    "#{folder}:#{ENV.fetch('PATH')}"
  end

  # The arguments of each call of a fake, one String per call.
  def fake_calls(dir)
    path = File.join(dir, 'calls')
    File.exist?(path) ? File.read(path).split("\0") : []
  end
end
