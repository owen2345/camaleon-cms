# frozen_string_literal: true

# The wait of wait-runs.sh: its header says what the wait prints, its exit codes and why one ruby process runs it.
$stdout.sync = true
dir = ARGV[0] && File.join(ARGV[0], 'tmp/rspec-runs')
active = lambda do
  next system('pgrep', '-f', '[r]spec', out: File::NULL) unless dir

  names = begin
    Dir.children(dir)
  rescue SystemCallError
    []
  end
  names.any? do |name|
    File.open(File.join(dir, name)) { |marker| !marker.flock(File::LOCK_SH | File::LOCK_NB) }
  rescue SystemCallError
    false
  end
end
# An empty REVIEW_LOOP_SLEEP gives the default too, as ${REVIEW_LOOP_SLEEP:-5} does in wait-log.sh.
seconds = ENV['REVIEW_LOOP_SLEEP']
seconds = '20' if seconds.to_s.empty?
180.times do |i|
  exit 0 unless active.call
  puts i + 1
  sleep(seconds.to_f) if i < 179
end
exit 4
