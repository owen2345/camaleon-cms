# frozen_string_literal: true

# Each run of the Camaleon suite leaves a run marker under tmp/rspec-runs and locks it while the run is active.
# At exit, the run names the other runs that were active during it in one line on stderr. docs/ai/run-markers.md
# tells how to read the line. A file system error of this tool must not fail the suite or change its exit status,
# so each such error prints a warning. The messages go through say, not warn: RUBYOPT=-W0 silences warn, and the
# line at exit is no warning.
module RspecRunMarker
  DIR = CAMALEON_CMS_ROOT.join('tmp/rspec-runs')
  NAME = /\Arspec-\d+-\d+\.pid\z/

  # The state of this run:
  # - name: the run marker of this run.
  # - file: the open file of the run marker, which keeps the lock.
  # - found: the run markers that the run found at load. An ended run keeps its run marker while a run is
  #   active, so found can hold the run marker of an ended run.
  # - active: the run markers in found whose runs held their lock at load.
  Run = Struct.new(:name, :file, :found, :active)

  module_function

  # Writes and locks the run marker of this run. The run locks the file before the file gets the name of the run
  # marker, so another run never finds the run marker unlocked. It refuses a temporary file or a run marker that
  # exists under its name. Two runs with the same pid and second therefore never share a file. When it cannot
  # write the run marker, it prints a warning and returns nil, and the run continues without a run marker
  # (intended).
  def write
    DIR.mkpath
    found = names
    active = found.select { |name| active?(name) }
    prune(found) if active.empty?
    name = "rspec-#{Process.pid}-#{Time.now.to_i}.pid"
    path = File.join(DIR, name)
    file = File.open("#{path}.tmp", File::WRONLY | File::CREAT | File::EXCL)
    file.flock(File::LOCK_EX)
    File.link(file.path, path)
    File.unlink(file.path)
    Run.new(name, file, found, active)
  rescue SystemCallError => e
    remove(file) if file
    say "RspecRunMarker: no run marker for this run: #{e.message}"
    nil
  end

  # Closes and removes the temporary file of a failed write. A second error must not escape the rescue of write.
  def remove(file)
    file.close
    File.unlink(file.path)
  rescue SystemCallError
    nil
  end

  # Prints the other runs that were active during the run. A run that was active at load counts, and a run that
  # wrote its run marker later counts too. A run without a run marker prints its warning again, so that a reader
  # of the end of the log sees it.
  def report(run)
    return say('RspecRunMarker: no run marker for this run') unless run

    others = (run.active | (names - run.found)) - [run.name]
    say "RspecRunMarker: other runs during this run: #{others.sort.join(' ')}" if others.any?
  rescue SystemCallError => e
    say "RspecRunMarker: cannot list the run markers at exit: #{e.message}"
  end

  # Prints a message on stderr. It ignores any error of the write, for example a pipe whose reader is gone or a
  # replaced stderr that cannot take the message.
  def say(message)
    $stderr.puts(message) # rubocop:disable Style/StderrPuts
  rescue StandardError
    nil
  end

  # A run is active while its process holds the lock of its run marker. The system releases the lock when the
  # process and its forked children end, also after kill -9. A reused pid or a clock change therefore cannot make
  # an ended run look active. The probe takes a shared lock, so two runs that probe one run marker at the same
  # time cannot make an ended run look active.
  #
  # A run marker that is gone, or that the run has no permission to open, counts as ended (intended). write
  # removes it with the other run markers of ended runs. Any other error reaches the rescue of write, which warns
  # and removes nothing. A failed probe therefore never removes the run marker of an active run.
  def active?(name)
    File.open(File.join(DIR, name)) { |file| !file.flock(File::LOCK_SH | File::LOCK_NB) }
  rescue Errno::ENOENT, Errno::EACCES, Errno::EPERM
    false
  end

  # Lists the names of the run markers in DIR in sorted order. Raises when the directory is gone or unreadable, so
  # write and report print a warning. Skips a name that is not valid in its encoding, because the match raises on
  # such a name.
  def names
    Dir.children(DIR).select(&:valid_encoding?).grep(NAME).sort
  end

  # Removes the run markers of the ended runs. write calls it with every run marker it found, only when no run is
  # active, because an active run can still name an ended run that started after it.
  def prune(ended)
    ended.each do |name|
      File.delete(File.join(DIR, name))
    rescue Errno::ENOENT
      # Another run removed the run marker after this run listed it.
    rescue SystemCallError => e
      say "RspecRunMarker: cannot remove an old run marker: #{e.message}"
    end
  end
end

# A run of rspec --dry-run also leaves a run marker (intended), because its load of rails_helper can change the
# shared test database.
RspecRunMarker::THIS_RUN = RspecRunMarker.write
# A forked child, for example a round of rspec --bisect, also runs this hook at its exit. The parent run is still
# active when the child exits, so only the process that loaded this file reports.
owner = Process.pid
at_exit { RspecRunMarker.report(RspecRunMarker::THIS_RUN) if Process.pid == owner }
