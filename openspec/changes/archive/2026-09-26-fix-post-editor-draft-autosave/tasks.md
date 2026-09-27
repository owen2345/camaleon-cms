## 1. The Preview link and the saved state (post-editor-draft-autosave)

- [x] 1.1 Point every Preview link at the draft after a successful save, into the form the save was sent from (design D8); cover the link after an autosave and a save returning after the form was replaced in `spec/features/admin/post_draft_autosave_spec.rb`; verify red before, green after.
- [x] 1.2 Compare the timer's form against the state the last successful save sent, read after the editors' change handlers ran, and send nothing before the load baseline exists (design D2); cover the unchanged form, a derived field and the second language of a translated field; verify red before, green after.

## 2. The load baseline and the comparison

- [x] 2.1 Take the baseline once every editor on the form has initialized, on its own timer, giving up after ten seconds, and leave a form the script was set up on later alone (design D4); cover an editor that comes up late and a wait that outlives its form; verify red before, green after.
- [x] 2.2 Make the comparison a read of the form's own editors, keyed by own property, leaving out the draft id field and a translated field's hidden original (design D3); cover a plugin's textarea export, an editor outside the form, a field named `constructor` and an edit made in the editor alone; verify red before, green after.

## 3. The asynchronous save

- [x] 3.1 Send the save asynchronously behind a lock with a queue, drained through the script's own function, skipping a queued timer call with nothing to send; release the lock when a callback or `$.ajax` throws and run the failure handler (design D1); cover one buffer for two overlapping saves, the queue past an idle timer call, a throwing callback, `$.ajax` throwing and a wrapper running once; verify red before, green after.
- [x] 3.2 Fail a save that has not returned after `App_post.save_timeout_ms`, report a failed request the user asked for with `msg.draft_save_failed` in every admin JS locale, and keep the timing values a plugin set (design D7); cover the timeout and the alert; verify red before, green after.
- [x] 3.3 On a refused save show the messages as text, run no callback, drop a held submit and the timer calls queued behind it; cover the dropped timer call; verify red before, green after.

## 4. Preview, Save Draft and the held submit

- [x] 4.1 Open the Preview window in the click, prevent the link's default first, send the window to the draft on success and close it on refusal or failure (design D6); cover a plain Preview, Preview during an autosave, a refused save and a save that could not be sent; verify red before, green after.
- [x] 4.2 Hold Save Draft's form under the overlay and give it back when the save is refused; cover the refused Save Draft; verify red before, green after.
- [x] 4.3 Hold a submit made while a save runs, before validation or any other listener sees it, until the save and its queued saves finish or `App_post.submit_wait_ms` passes, then dispatch it again in full to the form it was held on; keep the post on the form after a refused save, send it after a failed request, drop it when its form left the page (design D5); cover each case, the overlay kept for a queued save, listeners running once and a listener delegated from an ancestor; verify red before, green after.

## 5. Documentation

- [x] 5.1 Add the asynchronous-save section to `docs/upgrading-to-2.9.5.md` with a table row for plugin callers, and the `CHANGELOG.md` entry linking it.

## 6. Verification and wrap-up

- [x] 6.1 Run `bin/rubocop` with no offenses.
- [x] 6.2 Run `bin/rspec spec/features/admin/post_draft_autosave_spec.rb` and the adjacent draft request specs green.
- [x] 6.3 Run `bin/brakeman --no-pager` and confirm 0 warnings.
- [x] 6.4 Run `(cd spec/dummy && bin/rails zeitwerk:check)` and confirm "All is good".
- [x] 6.5 Run `openspec validate fix-post-editor-draft-autosave --strict` and confirm it passes.
- [x] 6.6 Archive the change with `/opsx:archive` on the branch and commit the archived change and the synced spec; verify `openspec list --json` shows no active change.
