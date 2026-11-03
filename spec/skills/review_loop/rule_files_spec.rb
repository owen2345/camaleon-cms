# frozen_string_literal: true

# The scripts that the rule files of the review loop name (procedure.md, Pass start). The skill names them as
# `<scripts>/<name>`, and docs/ai by their repository path. A call ends at the closing backtick.
RSpec.describe 'the scripts that the rule files name' do
  let(:rule_files) do
    Dir[CAMALEON_CMS_ROOT.join('.claude/skills/review-loop/*.md')] + Dir[CAMALEON_CMS_ROOT.join('docs/ai/*.md')]
  end

  # The path of a script in a call, which ends with its name.
  let(:script_path) { %r{(?:<scripts>|\.claude/skills/review-loop/scripts)/([\w-]+\.(?:sh|rb))} }

  # Each call: the name of the script and the count of its arguments, the placeholders after the name.
  let(:calls) do
    pattern = /#{script_path}((?: <[^<>`]+>)*)`/
    rule_files.flat_map { |file| File.read(file).scan(pattern) }.map { |name, args| [name, args.count('<')] }.uniq
  end

  let(:names) { calls.map(&:first).uniq.sort }

  it 'exist as executable files under .claude/skills/review-loop/scripts' do
    expect(names.size).to be > 10
    names.each do |name|
      path = ReviewLoopScripts::SCRIPTS.join(name)
      expect(path).to be_executable, "#{name} is not an executable script"
    end
  end

  it 'are called in one shape: the path, the placeholders of the arguments, and a closing backtick' do
    pattern = /#{script_path}([^`\n]*`?)/
    rule_files.each do |file|
      File.read(file).scan(pattern).each do |name, rest|
        expect(rest).to match(/\A(?: <[^<>`]+>)*`\z/), "#{File.basename(file)}: #{name}#{rest}"
      end
    end
  end

  it 'get the count of arguments that the usage line of each script allows' do
    calls.each do |name, count|
      usage = ReviewLoopScripts::SCRIPTS.join(name).read[/^# Usage: (.*)$/, 1]
      arguments = usage.sub(/.*\| /, '')
      required = arguments.scan(/(?<!\[)<[^<>]+>(?!\])/).size
      optional = arguments.scan(/\[<[^<>]+>\]/).size
      expect(count).to be_between(required, required + optional), "#{name} gets #{count} arguments; #{usage}"
    end
  end
end
