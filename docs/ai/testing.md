# Testing Guide

Run specs with `bin/rspec` (it forces `RAILS_ENV=test` and boots `spec/dummy`); `bin/rspec spec/path_spec.rb:12` runs one example. Rails commands go through `spec/dummy` in a subshell (`AGENTS.md` Ground rules).

## Which specs to run

`AGENTS.md` "Verify before pushing" says which specs to run before a push, how to find the adjacent ones, and when to run the whole suite. Never run two spec runs at once in one checkout. The suite shares one SQLite database, and runs on separate ones still share the dummy app's files, such as the uploads under `spec/dummy/public/media`.

Give `bin/rspec` only `*_spec.rb` files that exist. A deleted spec, a factory or a fixture fails to load, and a support file loads again and adds no example.

At exit, each run of the Camaleon suite names the run markers of the other runs that were active during it. Read `docs/ai/run-markers.md` only to judge a `RspecRunMarker` line in the output of a run.

`pgrep -f '[r]spec'`, in a command of its own, lists the active runs. The brackets keep the shell that runs the command off the list. Its command line holds the pattern, and the pgrep of Linux does not leave it out by itself. `ps -o args= -p <pid>` shows what a run is. `lsof -a -d cwd -p <pid>`, or `readlink /proc/<pid>/cwd` on Linux, shows the checkout that it runs in.

`<checkout>` is the real path of a checkout (`git rev-parse --show-toplevel`). To wait until no run of it is active, an hour at most: `for i in $(seq 180); do pgrep -f '[r]spec' | xargs -I{} lsof -a -d cwd -p {} -Fn 2> /dev/null | P='n<checkout>' awk '$0 == ENVIRON["P"] || index($0, ENVIRON["P"] "/") == 1 { f = 1 } END { exit !f }' || exit 0; echo "$i"; sleep 20; done; exit 4`. The `awk` matches the checkout and a directory below it as fixed strings. Without `lsof`, `readlink /proc/{}/cwd 2> /dev/null | sed 's/^/n/'` takes the place of the `lsof` command. Exit code 4: a run is still active after the hour.

For a host app on PostgreSQL, a run of any checkout counts: `for i in $(seq 180); do pgrep -f '[r]spec' > /dev/null || exit 0; echo "$i"; sleep 20; done; exit 4`. The `echo` keeps the log of a wait fresh: a log that does not change for 30 minutes means a hang (Long commands). Exit code 4: a run is still active after the hour, and `pgrep -f '[r]spec'` names it.

## Long commands

A foreground command of the Bash tool that reaches its timeout moves to the background and runs until the turn ends. It is a background task from then on: the message of the tool names its id and its log. Wait for it as below before any command that needs its result. The timeout is two minutes by default and ten minutes at most. Give the ten-minute timeout to a foreground command that can take longer than two minutes, and to every wait below.

Run every spec run, every CI poll and any other command that can outlast the timeout as a background task. A background task is the Bash tool with `run_in_background`. The tool answers with the task id and the path of the log of the task, `<log>`, which holds stdout and stderr of the command. When the command ends, the harness appends `[exited with code <n>]` to the log and sends a notification with the exit code. The notification arrives with the result of the next tool call. `TaskStop <task id>` writes `[killed]` to the log, then kills the command and its child processes, which can print more after that line.

Wait for the end, as often as needed: `w=bound; for i in $(seq 114); do grep -aqE '^\[(exited with code [0-9]+|killed)\]$' <log> && { w=end; break; }; [ -e <log> ] || { w=missing; break; }; [ -z "$(find <log> -mmin -30)" ] && { w=stale; break; }; sleep 5; done; echo $w; grep -aE '^[0-9]+ examples?, ' <log>; tail -n 3 <log>`. The wait prints one word, then the summary line of a spec run and the end of the log. It returns before the ten-minute timeout, so the harness moves no copy of it to the background. The word is one of these:

- `end`: the log has the end line.
- `missing`: the log does not exist, for example after the scratchpad of a session is gone. The command has no result.
- `stale`: the log did not change for 30 minutes. End the command with `TaskStop`. When `TaskStop` finds no task, the command died with its session: it has no result. When it answers `is not running`, the command ended: judge its log as for `end`. Otherwise the command hangs.
- `bound`: 570 seconds passed, and the command still runs. Wait again.

`grep -a` reads a log that holds a NUL byte or invalid UTF-8. Without it, the `grep` of the Bash tool skips such a file as binary.

Do not edit a checkout while a run is active in it in the background.

A spec run has one of three results. Test them in this order:

- It has no result when a signal stopped it. The signs are an exit code of 128 or above, a line `[killed]`, or `RSpec is shutting down` (an interrupt) with exit code 1. A killed run prints a summary line of the examples so far, or none. A signal that kills the shell of the task can leave `[exited with code 1]` and no error message.
- It passes with 0 failures in its summary line, no error outside of examples, and exit code 0. The exit code is the code of `bin/rspec` itself: a run piped through another command, such as `tail`, reports the code of that command.
- It fails with a failure or an error outside of examples in its summary line. A crash fails too: an error message, no summary line, and an exit code from 1 to 127.

A syntax error in a spec file does not stop the other files. Any other load failure, for example a spec file that does not exist, stops every example: the summary line starts with `0 examples`. In both cases the summary line ends with `1 error occurred outside of examples`, and `bin/rspec` exits with 1: the run failed, whatever its failure count.

Any other command has one of these results:

- A bisect has a result when its log holds `bisect found first 'bad' commit` or `error: bisect run cannot continue any more`: `docs/ai/failures.md` reads it. Otherwise it has no result. Its restart is `git bisect run <script>` alone: `git bisect start` drops the marks.
- A command whose exit code is 128 or above has no result: a signal killed it, or `git` itself failed.
- A log that ends with `[exited with code 1]` and holds no report of the command has no result: a signal killed the shell of the task (above).
- A log with a line `[killed]` has no result: `TaskStop` ended the command.
- For any other command, the exit code is the result.

## Database

`rails_helper` keeps the SQLite test schema current from `spec/dummy/db/schema.rb` (`maintain_test_schema!`); `bundle exec rake app:db:test:prepare` rebuilds it by hand.

## Helpers (`spec/support/common.rb`)

```ruby
init_site              # exposes the suite-wide shared site as @site (+ @post)
init_site(fresh: true) # a per-example site, only when the slug must match the
                       # Capybara server host (multi-site UI flows)
admin_sign_in          # sets the auth cookie directly (fast; verifies the password)
admin_form_sign_in     # the real login form; only for specs of the sign-in flow
wait(2)                # wait for JS
cama_root_relative_path
confirm_dialog         # accept JS dialogs
```

`sql_queries(matching:) { … }` collects the SQL a block issues, only the statements matching a pattern, or every
pattern of a list, when given, `metas_selects { … }` the SELECTs against the metas table and `metas_updates { … }`
the UPDATEs of it (`spec/support/sql_queries.rb`); count them to pin a query profile. `sql_queries` skips the
BEGIN, SAVEPOINT and COMMIT statements unless you pass `include_transactions: true`.

`rolled_back_transaction { … }` runs a block in a savepoint of its own and rolls it back, for specs of what a
rollback leaves on the records the block wrote.

### The shared site (`spec/support/shared_site.rb`)

Installing a site costs ~0.6s, so one canonical site is installed per suite run, committed outside the per-example transactions, and reused everywhere: `init_site`, `Cama::Site.first` and the `post`/`post_type`/`user` factories resolve to it, and example-level mutations roll back. Create another site only when the test is about multi-site behavior (`create(:site)` installs a real one). Installation already claims the default slugs — roles `admin`/`editor`/`contributor`/`client`, post types `post`/`page` — and slugs are unique per parent and taxonomy, so reuse those records (`site.user_roles.find_by!(slug: 'admin')`) instead of creating same-slug duplicates.

## Conventions

- A spec starts at the `# frozen_string_literal: true` magic comment: `.rspec` requires `rails_helper` for every file, so no spec requires it itself. Spec type is inferred from the directory (`spec/models`, `spec/requests`, `spec/features`, `spec/helpers`).
- `spec_helper` disables the RSpec monkey patches (`config.disable_monkey_patching!`). A top-level group must start with `RSpec.describe`, `RSpec.shared_examples` or `RSpec.shared_context`: a file with a bare `describe` does not load. The `should` and `stub` syntaxes do not exist.
- Factories live in `spec/factories/`; `rails_helper` points FactoryBot at them explicitly because `Rails.root` is `spec/dummy` and the default lookup finds nothing. The engine does not inject them into host apps — a host or plugin harness that wants them sets `FactoryBot.definition_file_paths` itself, as the cama_contact_form harness does. Site-owned factories default to the shared site; pass `site:` for another. `spec/factories/site.rb` shows the install-on-create pattern.
- Shared examples live in `spec/shared_specs/`: `it_behaves_like 'sanitize attrs', model: described_class, attrs_to_sanitize: %i[name description]` and `it_behaves_like 'i18n value translation safety', described_class`.
- Feature specs are tagged `:js`, call `init_site` and `admin_sign_in`, then `visit "#{cama_root_relative_path}/admin/…"`; `spec/features/admin/categories_spec.rb` is a compact example. Request specs (`spec/requests/`) are preferred over controller specs.

### JavaScript in feature specs

- Clear `spec/dummy/tmp/cache` and `spec/dummy/public/assets` before a red check of a change to the admin JavaScript: otherwise the browser may get the bundle compiled before the change, and the example passes on it.
- Hold what an example waits on instead of sleeping: `spec/features/admin/post_draft_autosave_spec.rb` wraps `$.ajax` so a draft request stays pending until the example releases it (`hold_draft_requests` / `release_draft_requests`), and loads an admin page in place as `camaleon_admin_ajax` does (`load_in_place`).
- To check that no alert opened, look for `body.modal-open`: Bootstrap adds the modal to the page only once its backdrop has faded in, so `have_no_css('#cama_alert_modal')` right after the answer that would open one passes either way.
- An error thrown, uncaught, in a later task by a function the example defined with `execute_script` reaches `window` error listeners as "Script error."; to read its message, add the code as an inline `<script>` of the page.
- In a window the page sends to a URL after opening it, wait with `have_current_path` before any DOM query: Chrome raises on a query that spans the navigation away from `about:blank`, and Capybara does not retry it. `window_opened_by` needs the window to stay open; for one that opens and closes inside the block, check `page.windows.size` instead.

## Ecosystem member checks

CI also runs five ecosystem members' suites against the commit under test (`<member> / RSpec` checks; what they are and what a red one means: `docs/ai/ecosystem.md`, "Continuous cross-testing"). To reproduce one locally, run the member's suite from a sibling checkout with `CAMALEON_CMS_PATH` pointing at this working tree. For a plugin:

```bash
cd ../cama_contact_form
export RAILS_ENV=test CAMALEON_CMS_PATH=../camaleon-cms
bundle lock && bundle install   # re-resolves camaleon_cms and what it newly requires, nothing else
(cd spec/dummy && bundle exec rails db:test:prepare && bundle exec rails db:migrate)
bin/rspec
unset CAMALEON_CMS_PATH && git checkout Gemfile.lock spec/dummy/db/schema.rb && bundle install
```

The last line matters: the member's committed lock belongs to the released gem. `camaleon_editor` has `:js` specs, so clear `spec/dummy/tmp/cache` and `spec/dummy/public/assets` first. `florsan` is a host app on Postgres that copies the engines' migrations: run `bin/rails railties:install:migrations`, `bin/rails db:test:prepare` and `bin/rails db:migrate` from its root instead, and restore `db/schema.rb` (and delete any migration the first command copied) afterwards.

## Security Vulnerability Reproduction

A vulnerability fix starts with a failing spec that reproduces it (`AGENTS.md` Ground rules); whether the report is legit is decided first by the triage protocol in `docs/ai/workflows.md` Phase 2A. Reproductions live in `spec/requests/security/`, driven through the real endpoint so the request context the permission decision reads is the real one. `repro_markup_and_script_upload_scanning_spec.rb` is the model: state the gap in the header comment, exercise it as the attacker would, and assert the safe outcome so the spec fails while the vulnerability is present.
