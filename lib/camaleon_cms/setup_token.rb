require 'securerandom'
require 'fileutils'

module CamaleonCms
  # Gates the first-run installer so setup can be completed only by someone with access to the
  # server's environment or filesystem — not by any anonymous visitor who reaches the app on a fresh
  # deploy (audit finding C1, vector 2). The expected token comes from ENV['CAMALEON_SETUP_TOKEN']
  # when set, otherwise from a generated 0600 file under tmp/; generating it logs its location once so
  # the operator can read it. It is required only while no site exists, and is cleared once one does.
  # See openspec/specs/installer-access-control/spec.md.
  module SetupToken
    ENV_KEY = 'CAMALEON_SETUP_TOKEN'.freeze

    module_function

    # The installer is gated only until the first site exists; afterwards it is closed anyway.
    def required?
      CamaleonCms::Site.count == 0
    rescue StandardError
      false
    end

    # The expected token: an explicit ENV override wins; otherwise a generated file (created on first
    # read). Returns nil only if no ENV value is set and the file cannot be created.
    def value
      env = ENV[ENV_KEY].to_s
      return env if env.present?

      read_or_generate_file
    end

    # Constant-time comparison; false for a blank candidate or when no expected token is available.
    def valid?(candidate)
      candidate = candidate.to_s
      expected = value.to_s
      return false if candidate.empty? || expected.empty?

      ActiveSupport::SecurityUtils.secure_compare(candidate, expected)
    end

    # Invalidate the generated token once setup has completed (the ENV override, if any, is untouched).
    def clear!
      File.delete(file_path) if File.exist?(file_path)
    rescue StandardError
      nil
    end

    def file_path
      Rails.root.join('tmp/camaleon_setup_token').to_s
    end

    def read_or_generate_file
      return File.read(file_path).strip if File.exist?(file_path)

      token = SecureRandom.hex(32)
      FileUtils.mkdir_p(File.dirname(file_path))
      # 0600 from the first byte (write-then-chmod would leave a world-readable window at default
      # umask), EXCL so a concurrent generator cannot clobber a token already handed to an operator.
      File.open(file_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(token) }
      Rails.logger.info("Camaleon CMS: setup token written to #{file_path} — required to run the installer.")
      token
    rescue Errno::EEXIST
      # Lost the creation race between the exist? check and the open: adopt the winner's token.
      read_or_generate_file
    rescue StandardError
      nil
    end
  end
end
