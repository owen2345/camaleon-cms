# frozen_string_literal: true

require 'open3'
require 'timeout'
require 'tmpdir'

# docs/ai/run-markers.md tells how a run writes its run marker and reports the other runs.
RSpec.describe RspecRunMarker do
  let(:dir) { Pathname(@tmp) }
  let(:runs) { dir.join('tmp/rspec-runs') }
  # The open files of the run markers that the examples hold, so that their locks hold until the example ends.
  let(:held) { [] }
  let(:children) { [] }
  # A run marker that sorts after the run markers of the child runs. Without the sort in report, the line names
  # it first.
  let(:older_run) { 'rspec-99999999-1.pid' }

  # The temporary directory of the example is the repo root of the runs. The block form removes it at the end.
  # An example fails after 15 seconds, so that a blocked call in the process of the suite does not stop the suite.
  # The child runs and the held files end before the block removes the directory.
  around do |example|
    Dir.mktmpdir('rspec-run-marker') do |tmp|
      @tmp = tmp
      Timeout.timeout(15, Timeout::Error, 'the example ran for more than 15 seconds') { example.run }
    ensure
      children.each do |run|
        stop(run)
        run[:stderr].close
      end
      held.each(&:close)
      # The block form cannot remove a run marker directory that an example left with mode 000.
      File.chmod(0o700, runs) if runs.exist?
    end
  end

  before do
    stub_const('RspecRunMarker::DIR', runs)
    FileUtils.mkdir_p(runs)
  end

  # Starts a run in a plain Ruby child with dir as the repo root. The child needs no gems, so it runs with
  # --disable-gems and with rubyopt in place of the RUBYOPT of Bundler. The run prints the name of its run marker
  # and ends when its stdin closes. It calls exit only when the example gives it a status, as RSpec calls exit
  # only after a failure. It forks a child first, which runs the exit hook too and must not print a second line.
  # A run that prints nothing in ten seconds fails the example.
  def start_run(status = nil, rubyopt: nil)
    script = <<~'RUBY'
      CAMALEON_CMS_ROOT = Pathname(ARGV[0])
      load ARGV[1]
      puts RspecRunMarker::THIS_RUN&.name
      $stdout.flush
      $stdin.read
      Process.wait(fork {})
      exit Integer(ARGV[2]) unless ARGV[2].empty?
    RUBY
    support = CAMALEON_CMS_ROOT.join('spec/support/run_marker.rb').to_s
    command = [RbConfig.ruby, '--disable-gems', '-rpathname', '-e', script, dir.to_s, support, status.to_s]
    stdin, stdout, stderr, thread = Open3.popen3({ 'RUBYOPT' => rubyopt }, *command)
    run = { stdin: stdin, stdout: stdout, stderr: stderr, thread: thread }
    children << run
    stdout.timeout = 10
    run[:marker] = stdout.gets.to_s.chomp
    run
  end

  # Closes the stdin of the run, so the run exits, waits for it and returns its status. Kills a run that does not
  # exit in ten seconds. The kill raises ESRCH when the run exited between the wait and the kill, and stop
  # ignores it. Closes the stdout of the run, which the second call from the around hook finds closed.
  def stop(run)
    run[:stdin].close
    begin
      Process.kill('KILL', run[:thread].pid) unless run[:thread].join(10)
    rescue Errno::ESRCH
      nil
    end
    run[:stdout].close
    run[:thread].value
  end

  # Stops the run and returns its stderr and its status.
  def finish(run)
    status = stop(run)
    error = run[:stderr].read
    run[:stderr].close
    [error, status]
  end

  # Writes a run marker and takes the lock on it. LOCK_EX holds it as the process of an active run does. LOCK_SH
  # holds it as the probe of another run does.
  def hold(name, lock = File::LOCK_EX)
    held << File.open(runs.join(name), File::WRONLY | File::CREAT).tap do |file|
      file.flock(lock)
    end
  end

  # The line that a run prints at exit. The names must be in sorted order, as report prints them.
  def line(*names)
    "RspecRunMarker: other runs during this run: #{names.join(' ')}\n"
  end

  # Fixes the time that write reads as the start, 0.9 s into the second: only a truncation gives that second.
  def at_clock(seconds)
    allow(Time).to receive(:now).and_return(Time.at(seconds, 900, :millisecond).utc)
  end

  # Writes the run marker of this process and keeps its file open until the example ends. A nil from write fails
  # the example at once, next to the warning that write printed.
  def write_held
    run = described_class.write
    expect(run).to be_a(described_class::Run)
    held << run.file
    run
  end

  # Expects write to print one line, the warning with the message of the error, and to return nil.
  def expect_no_run_marker(error)
    warning = "RspecRunMarker: no run marker for this run: #{error.new.message}"
    expect { expect(described_class.write).to be_nil }.to output(one_line(warning)).to_stderr
  end

  # Matches one line of stderr that starts with the text.
  def one_line(text)
    /\A#{Regexp.escape(text)}[^\n]*\n\z/
  end

  it 'reports the runs that were active at load or started later, also in a failed run, and only once' do
    hold(older_run)
    run = start_run(3)
    later = start_run
    later_error, later_status = finish(later)
    error, status = finish(run)

    expect(status.exitstatus).to eq(3), error
    expect(error).to eq(line(later[:marker], older_run))
    expect(later_status).to be_success, later_error
    expect(later_error).to eq(line(run[:marker], older_run))
  end

  it 'does not name an ended run whose run marker stays while a run is active' do
    hold(older_run)
    FileUtils.touch(runs.join('rspec-200-5.pid'))

    error, status = finish(start_run)

    expect(status).to be_success, error
    expect(error).to eq(line(older_run))
    expect(runs.join('rspec-200-5.pid')).to exist
  end

  it 'reports nothing when no other run was active' do
    FileUtils.touch(runs.join("rspec-200-#{Time.now.to_i}.pid"))

    error, status = finish(start_run)

    expect(status).to be_success, error
    expect(error).to be_empty
  end

  it 'prints the line also when RUBYOPT=-W0 silences Kernel#warn' do
    hold(older_run)

    error, status = finish(start_run(rubyopt: '-W0'))

    expect(status).to be_success, error
    expect(error).to eq(line(older_run))
  end

  it 'releases the lock when another process kills the run without its exit hooks' do
    run = start_run

    expect(described_class.active?(run[:marker])).to be(true)
    Process.kill('KILL', run[:thread].pid)
    run[:thread].join
    expect(described_class.active?(run[:marker])).to be(false)
  end

  it 'does not wait for the lock of another run' do
    run = start_run
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    expect(described_class.active?(run[:marker])).to be(true)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1
  end

  it 'warns at load and again at exit when it cannot write its run marker, and keeps the exit status' do
    FileUtils.remove_entry(dir.join('tmp'))
    FileUtils.touch(dir.join('tmp'))

    run = start_run(3)
    error, status = finish(run)

    expect(run[:marker]).to be_empty
    expect(status.exitstatus).to eq(3), error
    warning = 'RspecRunMarker: no run marker for this run'
    expect(error).to match(/\A#{warning}: [^\n]+\n#{warning}\n\z/)
  end

  it 'creates the run marker directory when it does not exist' do
    FileUtils.remove_entry(dir.join('tmp'))

    expect(runs.join(write_held.name)).to exist
  end

  it 'removes its temporary file when it cannot link it to its name' do
    allow(File).to receive(:link).and_raise(Errno::EACCES)

    expect_no_run_marker(Errno::EACCES)
    expect(Dir.children(runs)).to be_empty
  end

  it 'continues without a run marker when the run marker directory is gone before it links the temporary file' do
    allow(File).to receive(:link).and_wrap_original do |link, from, to|
      FileUtils.remove_entry(runs)
      link.call(from, to)
    end

    expect_no_run_marker(Errno::ENOENT)
    expect(runs).not_to exist
  end

  it 'adds no exit hook when it writes a run marker' do
    # The hook is at the file level. The examples call write in the process of the suite, so a hook inside write
    # adds a second line at the exit of the suite.
    expect(described_class).not_to receive(:at_exit)
    expect(Kernel).not_to receive(:at_exit)

    write_held
  end

  context 'when the clock is at a fixed second' do
    let(:second) { 1_700_000_000 }
    let(:name) { "rspec-#{Process.pid}-#{second}.pid" }

    before { at_clock(second) }

    it 'writes an empty run marker named with the pid and the start in Unix seconds, and locks it' do
      run = write_held

      expect(run.name).to eq(name)
      expect(File).to be_empty(runs.join(run.name))
      expect(described_class.active?(run.name)).to be(true)
    end

    it 'locks the run marker before it appears under its name' do
      locked_before_link = nil
      allow(File).to receive(:link).and_wrap_original do |link, from, to|
        locked_before_link = described_class.active?(File.basename(from)) && !File.exist?(to)
        link.call(from, to)
      end

      write_held

      expect(locked_before_link).to be(true)
      expect(Dir.children(runs)).to eq([name])
    end

    it 'keeps a run marker that exists under its name and continues without a run marker' do
      first = write_held

      expect_no_run_marker(Errno::EEXIST)
      expect(Dir.children(runs)).to eq([first.name])
      expect(described_class.active?(first.name)).to be(true)
    end

    it 'continues without a run marker when a temporary file exists under its name' do
      FileUtils.touch(runs.join("#{name}.tmp"))

      expect_no_run_marker(Errno::EEXIST)
      expect(Dir.children(runs)).to eq(["#{name}.tmp"])
    end

    it 'leaves a second run marker when a later run gets the same pid' do
      first = write_held
      at_clock(second + 60)
      later = write_held

      expect(first.name).not_to eq(later.name)
      expect(runs.join(first.name)).to exist
      expect(runs.join(later.name)).to exist
    end
  end

  it 'keeps the run markers of the ended runs while a run is active, also one with an earlier start' do
    ended = ['rspec-300-999.pid', 'rspec-500-999.pid', 'rspec-600-1001.pid']
    FileUtils.touch(ended.map { |name| runs.join(name) })
    File.chmod(0, runs.join('rspec-500-999.pid'))
    hold('rspec-400-1000.pid')

    run = write_held

    expect(Dir.children(runs)).to contain_exactly(*ended, 'rspec-400-1000.pid', run.name)
  end

  it 'removes every run marker of an ended run when no run is active, also an unreadable one, and keeps other files' do
    kept = ['rspec-abc-1.pid', 'old-rspec-200-1.pid', 'notes.txt', 'rspec-1.pid', 'rspec-100-1.pid.tmp']
    ended = ['rspec-300-999.pid', 'rspec-500-999.pid', "rspec-100-#{Time.now.to_i}.pid"]
    FileUtils.touch((kept + ended).map { |name| runs.join(name) })
    File.chmod(0, runs.join('rspec-500-999.pid'))

    run = write_held

    expect(Dir.children(runs)).to contain_exactly(*kept, run.name)
  end

  it 'removes old run markers, skips one that another run removed, warns when a removal fails, and writes its own' do
    raced, denied, removed = %w[rspec-100-1.pid rspec-200-1.pid rspec-300-1.pid].map { |name| runs.join(name).to_s }
    FileUtils.touch([raced, denied, removed])
    allow(File).to receive(:delete).and_call_original
    expect(File).to receive(:delete).with(raced).once.and_raise(Errno::ENOENT)
    expect(File).to receive(:delete).with(denied).once.and_raise(Errno::EACCES)
    warning = "RspecRunMarker: cannot remove an old run marker: #{Errno::EACCES.new.message}"
    run = nil

    expect { run = write_held }.to output(one_line(warning)).to_stderr

    expect(File).not_to exist(removed)
    expect(runs.join(run.name)).to exist
  end

  it 'does not count a run marker that another run removed' do
    expect(described_class.active?('rspec-100-1.pid')).to be(false)
  end

  it 'does not count a run marker that another run holds with a shared lock' do
    hold('rspec-100-1.pid', File::LOCK_SH)

    expect(described_class.active?('rspec-100-1.pid')).to be(false)
  end

  it 'counts a run marker that it cannot open as ended, and still writes its own' do
    skip 'root can open every file' if Process.euid.zero?
    unreadable = runs.join("rspec-100-#{Time.now.to_i}.pid")
    FileUtils.touch(unreadable)
    File.chmod(0, unreadable)

    expect(described_class.active?(unreadable.basename.to_s)).to be(false)
    run = write_held

    expect(run.active).to be_empty
  end

  it 'counts a run marker as ended when the open raises EPERM' do
    hold('rspec-100-1.pid')
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(runs.join('rspec-100-1.pid').to_s).and_raise(Errno::EPERM)

    expect(described_class.active?('rspec-100-1.pid')).to be(false)
  end

  it 'keeps the run marker of an active run and continues without a run marker when its probe fails' do
    hold('rspec-100-1.pid')
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(runs.join('rspec-100-1.pid').to_s).and_raise(Errno::EIO)

    expect_no_run_marker(Errno::EIO)
    expect(File).to exist(runs.join('rspec-100-1.pid'))
  end

  it 'names a run that was active at load, also when its run marker is gone at exit' do
    run = described_class::Run.new(name: 'rspec-1-1.pid', found: ['rspec-100-1.pid'], active: ['rspec-100-1.pid'])

    expect { described_class.report(run) }.to output(line('rspec-100-1.pid')).to_stderr
  end

  it 'ignores any error of stderr at exit, so that the exit status stays' do
    run = described_class::Run.new(name: 'rspec-1-1.pid', found: [], active: ['rspec-100-1.pid'])

    # A pipe whose reader is gone, a closed stream, a replaced stderr without puts, a stderr that transcodes.
    [Errno::EPIPE, IOError, NoMethodError, Encoding::UndefinedConversionError].each do |error|
      allow($stderr).to receive(:puts).and_raise(error)

      expect { described_class.report(run) }.not_to raise_error
    end
  end

  it 'keeps the exit status of a run whose stderr has no reader' do
    hold(older_run)
    run = start_run(3)
    run[:stderr].close

    expect(stop(run).exitstatus).to eq(3)
  end

  it 'warns, prints no line and keeps the exit status when the run marker directory is gone at exit' do
    run = start_run(3)
    FileUtils.remove_entry(runs)

    error, status = finish(run)

    expect(status.exitstatus).to eq(3), error
    warning = "RspecRunMarker: cannot list the run markers at exit: #{Errno::ENOENT.new.message}"
    expect(error).to match(one_line(warning))
  end

  it 'warns, prints no line and keeps the exit status when it cannot read the run marker directory at exit' do
    skip 'root can read every directory' if Process.euid.zero?
    run = start_run(3)
    File.chmod(0, runs)

    error, status = finish(run)

    expect(status.exitstatus).to eq(3), error
    warning = "RspecRunMarker: cannot list the run markers at exit: #{Errno::EACCES.new.message}"
    expect(error).to match(one_line(warning))
  end

  it 'lists the run markers in sorted order and skips a name that is not valid UTF-8' do
    allow(Dir).to receive(:children).and_call_original
    allow(Dir).to receive(:children).with(runs).and_return(['rspec-200-1.pid', "rspec-200-\xFF.pid", 'rspec-100-1.pid'])

    expect(described_class.names).to eq(['rspec-100-1.pid', 'rspec-200-1.pid'])
  end
end
