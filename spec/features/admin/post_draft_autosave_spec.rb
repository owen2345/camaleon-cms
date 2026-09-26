# frozen_string_literal: true

# The post editor autosaves a draft buffer every minute while the form has changed since its last save.
# `App_post.save_draft_ajax(null, true)` is what the timer runs, so the examples call it directly.
describe 'Post editor draft autosave', :js do
  let!(:site) { CamaleonCms::Site.first.decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let(:new_post_path) { "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new" }

  # Gives a new post what its save requires besides the title: a body and a category.
  def publishable_post_js
    <<~JS
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
    JS
  end

  # Keeps the page on a submit, as an in-place plugin does: a listener delegated from the body, which sees
  # a held submit only once the hold ends. `before_keeping` runs first.
  def keep_page_js(before_keeping = '')
    "$('body').on('submit', 'form#form-post', function () { #{before_keeping}return false; });"
  end

  # The same listener, counting the submits it sees in window.delegatedRuns.
  def count_kept_submits_js
    "window.delegatedRuns = 0; #{keep_page_js('window.delegatedRuns++; ')}"
  end

  # The hold ended: its overlay comes down within seconds and the kept listener saw the one submit.
  def expect_held_submit_delivered_once
    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_no_css('#cama_custom_loading', wait: 5)
    expect(page.evaluate_script('window.delegatedRuns')).to eq(1)
  end

  # An alert's modal joins the DOM only once its backdrop has faded in (Bootstrap), so a check for the modal
  # right after the answer that would open it finds nothing either way; the body is marked as one opens.
  def expect_no_alert
    expect(page).to have_no_css('body.modal-open')
  end

  def new_post_buffers
    CamaleonCms::Post.where(status: 'draft_child', post_parent: nil)
  end

  # Polls until the block returns a truthy value, for a condition no Capybara matcher expresses.
  def wait_until(seconds = 5)
    Timeout.timeout(seconds) { sleep(0.1) until yield }
  end

  # The editor script puts the permalink widget on the form as it runs.
  def wait_for_editor_setup
    expect(page).to have_css('#form-post .sl-slug-edit', visible: :all)
  end

  # The baseline can take up to ten seconds when an editor never comes up.
  def wait_for_editor_baseline
    wait_for_editor_setup
    wait_until(15) { page.evaluate_script('$("#form-post").data("hash") !== undefined') }
  end

  # Counts the draft requests sent from here on (ajaxSend fires when a request is made).
  def count_draft_saves
    page.execute_script(<<~JS)
      window.draftSaves = 0;
      $(document).ajaxSend(function (e, xhr, settings) {
        if (/\\/drafts(\\/|$)/.test(settings.url)) window.draftSaves++;
      });
    JS
  end

  def draft_saves
    page.evaluate_script('window.draftSaves')
  end

  # The prompt is installed by the editor script's setup, before the baseline.
  def wait_for_leave_prompt
    wait_until { page.evaluate_script('typeof window.onbeforeunload === "function"') }
  end

  # Removes the content editor and recreates it `wait_ms` later, which delays the baseline by as much.
  def delay_content_editor(wait_ms = 3000)
    page.execute_script(<<~JS)
      (function delayEditor() {
        var editor = tinymce.get('post_content');
        if (!editor) return setTimeout(delayEditor, 10);
        editor.remove();
        setTimeout(function () {
          tinymce.init(cama_get_tinymce_settings({ selector: '#post_content', height: '480px' }));
        }, #{wait_ms});
      })();
    JS
  end

  # Adds a textarea the baseline waits for; init_late_editor creates its editor.
  def add_late_editor
    page.execute_script(<<~JS)
      $('#form-post').append('<textarea id="late_editor" name="late_editor" class="tinymce_textarea"></textarea>');
    JS
  end

  def init_late_editor
    page.execute_script("tinymce.init(cama_get_tinymce_settings({ selector: '#late_editor', height: 100 }));")
  end

  def autosave_tick
    page.execute_script('App_post.save_draft_ajax(null, true)')
  end

  # Routes the editor's draft requests through `handler(options, send)`: `send` sends the request for real,
  # and the handler's return value goes back to the caller. A returned promise gets an `abort` that runs the
  # request's error handler with the given status, after which answers are dropped, as jQuery drops them.
  # Requests are counted in window.interceptedDraftRequests, answers (a success or error handler run to its
  # end) in window.interceptedDraftAnswers.
  def intercept_draft_requests(handler)
    page.execute_script(<<~JS)
      window.interceptedDraftRequests = 0;
      window.interceptedDraftAnswers = 0;
      (function (ajax, handler) {
        $.ajax = function (options) {
          var self = this, args = arguments, aborted = false;
          if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(self, args);
          window.interceptedDraftRequests++;
          $.each(['success', 'error'], function (i, name) {
            var answer = options[name];
            options[name] = function () {
              if (aborted) return;
              try { return answer.apply(this, arguments); } finally { window.interceptedDraftAnswers++; }
            };
          });
          var request = handler(options, function () { return ajax.apply(self, args); });
          if (request && !request.abort) {
            request = { abort: function (status) {
              try { options.error(this, status || 'abort', ''); } finally { aborted = true; }
            } };
          }
          return request;
        };
      })($.ajax, #{handler});
    JS
  end

  def intercepted_draft_requests
    page.evaluate_script('window.interceptedDraftRequests')
  end

  # By the time an answer is counted, everything its handler did is done.
  def wait_for_draft_answers(count)
    wait_until { page.evaluate_script('window.interceptedDraftAnswers') == count }
  end

  # Draft requests never return.
  def stall_draft_requests
    intercept_draft_requests('function () { return $.Deferred().promise(); }')
  end

  # Each draft request is sent `wait_ms` later, so a save is in flight for that long.
  def delay_draft_requests(wait_ms)
    intercept_draft_requests("function (options, send) { setTimeout(send, #{wait_ms}); return $.Deferred().promise() }")
  end

  # Each draft request fails `wait_ms` later, as when the transport reports an error.
  def fail_draft_requests(wait_ms)
    intercept_draft_requests(<<~HANDLER)
      function (options) {
        setTimeout(function () { options.error({}, "error", ""); }, #{wait_ms});
        return $.Deferred().promise();
      }
    HANDLER
  end

  # Each draft request is refused `wait_ms` later with `message`, as the server refuses one.
  def refuse_draft_requests(message, wait_ms)
    intercept_draft_requests(<<~HANDLER)
      function (options) {
        setTimeout(function () { options.success({ error: [#{message.to_json}] }); }, #{wait_ms});
        return $.Deferred().promise();
      }
    HANDLER
  end

  # The first draft request is answered with `response` (a JavaScript expression) `wait_ms` later, as the
  # server would answer it; the requests after it are sent for real.
  def answer_first_draft_request(response, wait_ms = 200)
    intercept_draft_requests(<<~HANDLER)
      (function () {
        var answered = false;
        return function (options, send) {
          if (answered) return send();
          answered = true;
          setTimeout(function () { options.success(#{response}); }, #{wait_ms});
          return $.Deferred().promise();
        };
      })()
    HANDLER
  end

  # The first draft request throws `message` before it is sent; the requests after it are sent for real.
  def throw_from_first_draft_request(message)
    intercept_draft_requests(<<~HANDLER)
      (function () {
        var thrown = false;
        return function (options, send) {
          if (thrown) return send();
          thrown = true;
          throw new Error(#{message.to_json});
        };
      })()
    HANDLER
  end

  before { admin_sign_in }

  # The permalink widget writes `?draft_id=` into the Preview link before a new post has a draft, and an
  # autosave created the draft without updating it: opening Preview in a new tab showed no draft.
  it 'points the Preview link at the draft an autosave created' do
    visit new_post_path
    wait_for_editor_baseline

    fill_in 'post_title', with: 'Autosaved title'
    autosave_tick
    wait_for_ajax

    buffer = new_post_buffers.order(:id).last
    expect(buffer.title).to eq('Autosaved title')
    expect(page).to have_css(".btn-preview[href$='draft_id=#{buffer.id}']")
  end

  # The timer compared with the page-load snapshot, never refreshed, so it re-sent the form every minute.
  it 'does not resend a form that has not changed since the last autosave' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    fill_in 'post_title', with: 'First title'
    autosave_tick
    wait_for_ajax

    autosave_tick
    expect(draft_saves).to eq(1)

    fill_in 'post_title', with: 'Second title'
    autosave_tick
    expect(draft_saves).to eq(2)
    wait_for_ajax
    expect(new_post_buffers.order(:id).last.title).to eq('Second title')
  end

  # A tick that starts while a new post's first save is in flight must wait for its draft id, or it creates
  # a second buffer.
  it 'creates one buffer when a second autosave starts while the first is in flight' do
    visit new_post_path
    wait_for_editor_baseline

    expect do
      page.execute_script(<<~JS)
        $('#post_title').val('First').trigger('keyup');
        App_post.save_draft_ajax(null, true);
        $('#post_title').val('Second').trigger('keyup');
        App_post.save_draft_ajax(null, true);
      JS
      wait_for_ajax
    end.to change(new_post_buffers, :count).by(1)
    expect(new_post_buffers.order(:id).last.title).to eq('Second')
  end

  # A queued timer call may find nothing to send; the saves behind it must still run.
  it 'runs the saves queued behind a timer call that had nothing to send' do
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script(<<~JS)
      $('#post_title').val('Queued').trigger('keyup');
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, true);
      App_post.save_draft_ajax(function () { window.queuedSaveRan = true; }, false);
    JS
    wait_for_ajax

    expect(page.evaluate_script('window.queuedSaveRan')).to be(true)
  end

  # One timer call waits in the queue at a time: on a request that never returns, a second one every minute
  # would pile up, each comparing the same form.
  it 'queues one timer call behind a running save' do
    visit new_post_path
    wait_for_editor_baseline
    # Draft requests are counted as the editor makes them and sent a second later.
    intercept_draft_requests(<<~HANDLER)
      (function () {
        window.draftRequests = 0;
        window.draftsDone = 0;
        return function (options, send) {
          window.draftRequests++;
          setTimeout(function () { send().always(function () { window.draftsDone++; }); }, 1000);
          return $.Deferred().promise();
        };
      })()
    HANDLER

    page.execute_script(<<~JS)
      $('#post_title').val('First').trigger('keyup');
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, true);
      App_post.save_draft_ajax(null, true);
      $('#post_title').val('Second').trigger('keyup');
    JS
    # The first save returns and the timer call waiting behind it sends the edit made meanwhile.
    wait_until { page.evaluate_script('window.draftRequests') == 2 }
    page.execute_script("$('#post_title').val('Third').trigger('keyup');")
    wait_until { page.evaluate_script('window.draftsDone') == 2 }

    # A second timer call waiting would have sent the third title as the second save returned.
    expect(page.evaluate_script('window.draftRequests')).to eq(2)
    autosave_tick
    expect(page.evaluate_script('window.draftRequests')).to eq(3)
    wait_until { page.evaluate_script('window.draftsDone') == 3 }
  end

  # jQuery skips `complete` when a success handler throws; the lock must still be released.
  it 'runs later saves after a save callback throws' do
    visit new_post_path
    wait_for_editor_baseline

    # The throw also leaves jQuery.active raised, so wait on the page's own markers, not wait_for_ajax.
    page.execute_script(<<~JS)
      $('#post_title').val('Thrown').trigger('keyup');
      App_post.save_draft_ajax(function () {
        $('body').attr('data-throwing-save', 'ran');
        throw new Error('callback failed');
      }, false);
    JS
    expect(page).to have_css('body[data-throwing-save="ran"]')

    page.execute_script(<<~JS)
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # $.ajax can throw before sending (a plugin wrapper): the lock is released and the failure handler runs,
  # since it is what takes the caller's overlay or window down.
  it 'runs later saves and the failure handler after $.ajax threw before sending one' do
    visit new_post_path
    wait_for_editor_baseline

    # The first draft request throws; the ones after it are sent.
    throw_from_first_draft_request('refused to send')
    page.execute_script(<<~JS)
      $('#post_title').val('Thrown before sending').trigger('keyup');
      try {
        App_post.save_draft_ajax(null, false, function () { window.sendFailed = true; });
      } catch (e) { window.sendThrew = e.message; }
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS

    expect(page.evaluate_script('window.sendThrew')).to eq('refused to send')
    expect(page.evaluate_script('window.sendFailed')).to be(true)
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # A throwing failure handler must not replace the send's error on its way to the caller.
  it 'reports the send error to the caller when the failure handler of an unsent save throws' do
    visit new_post_path
    wait_for_editor_baseline

    throw_from_first_draft_request('refused to send')
    page.execute_script(<<~JS)
      try {
        App_post.save_draft_ajax(null, false, function () { throw new Error('handler failed'); });
      } catch (e) { window.sendThrew = e.message; }
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS

    expect(page.evaluate_script('window.sendThrew')).to eq('refused to send')
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # A queued save runs from the finished save's completion, inside its error path when it threw. A drained
  # save that throws too must not replace that error.
  it 'reports the send error to the caller when a save drained behind it throws too' do
    visit new_post_path
    wait_for_editor_baseline

    # The first two draft requests throw, each with its own message; the ones after them are sent.
    intercept_draft_requests(<<~HANDLER)
      (function () {
        var thrown = 0;
        return function (options, send) {
          if (thrown == 2) return send();
          throw new Error('refused to send ' + ++thrown);
        };
      })()
    HANDLER
    page.execute_script(<<~JS)
      // A change handler asks for a save of its own while the first is prepared: it queues behind it.
      var asked = false;
      $('#post_content').on('change', function () {
        if (asked) return;
        asked = true;
        App_post.save_draft_ajax(null, false, function () { window.queuedSendFailed = true; });
      });
      $('#post_title').val('Thrown twice').trigger('keyup');
      try {
        App_post.save_draft_ajax(null, false);
      } catch (e) { window.sendThrew = e.message; }
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS

    expect(page.evaluate_script('window.sendThrew')).to eq('refused to send 1')
    expect(page.evaluate_script('window.queuedSendFailed')).to be(true)
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # A change handler run by the sync may ask for a save; it must queue, or a new post gets two buffers.
  it 'queues a save a change handler asks for while the editors are synced' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved from a change handler'
    count_draft_saves

    page.execute_script(<<~JS)
      var asked = false;
      $('#post_content').on('change', function () {
        if (asked) return;
        asked = true;
        App_post.save_draft_ajax(function () { $('body').attr('data-handler-save', 'ran'); }, false);
      });
      tinymce.get('post_content').setContent('Body');
      App_post.save_draft_ajax(null, false);
    JS

    expect(page).to have_css('body[data-handler-save="ran"]')
    expect(draft_saves).to eq(2)
    expect(new_post_buffers.count).to eq(1)
  end

  # A change handler can throw during the sync, before the send.
  it 'runs the failure handler and frees the lock when a change handler throws before the send' do
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script(<<~JS)
      var failing = true;
      $('#post_content').on('change', function () { if (failing) throw new Error('handler failed'); });
      $('#post_title').val('Thrown by a handler').trigger('keyup');
      try {
        App_post.save_draft_ajax(null, false, function () { window.sendFailed = true; });
      } catch (e) { window.sendThrew = e.message; }
      failing = false;
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS

    expect(page.evaluate_script('window.sendThrew')).to eq('handler failed')
    expect(page.evaluate_script('window.sendFailed')).to be(true)
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # Submitting during a new post's first save used to post an empty draft id, leaving the buffer behind.
  it 'discards the new post buffer when the post is submitted during an autosave' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted during autosave'

    page.execute_script(<<~JS)
      #{publishable_post_js}
      App_post.save_draft_ajax(null, true);
      $('#form-post').submit();
    JS

    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted during autosave', status: 'published')).to be_present
    expect(new_post_buffers).to be_empty
  end

  # A save that never returns must not block the post: the held submit goes out after submit_wait_ms.
  it 'submits the post after a while when the draft save in flight never returns' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted during a stalled save'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 2000;
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_css('#cama_custom_loading')
    # The held submit is sent only once submit_wait_ms has passed, beyond Capybara's default wait.
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 10)
    expect(CamaleonCms::Post.find_by(title: 'Submitted during a stalled save', status: 'published')).to be_present
  end

  # A theme that wants no hold sets submit_wait_ms to 0, which must be kept, not defaulted.
  it 'sends a held submit at once when submit_wait_ms is zero' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted with no hold'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 0;
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted with no hold', status: 'published')).to be_present
  end

  # Likewise, save_timeout_ms 0 means no timeout.
  it 'sends the draft request with no timeout when save_timeout_ms is zero' do
    visit new_post_path
    wait_for_editor_baseline

    intercept_draft_requests('function (options, send) { window.draftTimeout = options.timeout; return send(); }')
    page.execute_script(<<~JS)
      App_post.save_timeout_ms = 0;
      $('#post_title').val('Sent with no timeout').trigger('keyup');
      App_post.save_draft_ajax(null, false);
    JS
    wait_for_ajax

    expect(page.evaluate_script('window.draftTimeout')).to eq(0)
    expect(new_post_buffers.order(:id).last.title).to eq('Sent with no timeout')
  end

  # When the fallback wait sends the held submit, the post save reports for itself: the running save is
  # aborted, so no late answer runs its callback (Save Draft's leaves the page) or shows an alert. The
  # failure handler runs and the page stays (a delegated listener keeps it, as an in-place plugin does).
  it 'aborts the draft save when the fallback wait sends the held submit' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Aborted by the fallback wait'

    # The request never returns on its own; the editor's abort is recorded and answered as jQuery would.
    intercept_draft_requests(<<~HANDLER)
      function (options) {
        return { abort: function (status) { window.abortedWith = status; options.error(this, status, ''); } };
      }
    HANDLER
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 500;
      #{count_kept_submits_js}
      #{publishable_post_js}
      App_post.save_draft();
      $('#form-post').submit();
    JS

    expect_held_submit_delivered_once
    expect(page.evaluate_script('window.abortedWith')).to eq('submit')
    expect_no_alert
    expect(page).to have_current_path(new_post_path, ignore_query: true)
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to eq(1)
  end

  # jQuery answers a request it cannot send inside `$.ajax` (a `beforeSend` that returns false, a transport
  # that throws): the save finishes and drains the queue before `$.ajax` returns, so the drained save's
  # request is the one the fallback wait must abort.
  it 'aborts the save drained behind one answered inside $.ajax when the fallback wait sends the held submit' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Aborted behind a save answered at once'

    # The first draft request fails before $.ajax returns; the second never returns on its own and records
    # the editor's abort.
    intercept_draft_requests(<<~HANDLER)
      (function () {
        var first = true;
        return function (options) {
          if (first) { first = false; options.error({}, 'error', ''); return; }
          return { abort: function (status) { window.abortedWith = status; options.error(this, status, ''); } };
        };
      })()
    HANDLER
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 500;
      #{count_kept_submits_js}
      #{publishable_post_js}
      // A change handler queues a save behind the timer's while its editors are synced; the queue is
      // drained inside the timer's $.ajax call.
      var asked = false;
      $('#post_content').on('change', function () {
        if (asked) return;
        asked = true;
        App_post.save_draft_ajax(null, false, function () { window.queuedSaveFailed = true; });
      });
      App_post.save_draft_ajax(null, true);
      $('#form-post').submit();
    JS

    expect_held_submit_delivered_once
    expect(page.evaluate_script('window.abortedWith')).to eq('submit')
    expect(page.evaluate_script('window.queuedSaveFailed')).to be(true)
    expect(intercepted_draft_requests).to eq(2)
    expect_no_alert
  end

  # After the fallback sent the submit no save is running, so a second submit is not held.
  it 'lets a submit made after the fallback wait sent one through at once' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted again after the fallback wait'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 500;
      #{count_kept_submits_js}
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS
    expect_held_submit_delivered_once

    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      $('#form-post').submit();
    JS
    expect(page.evaluate_script('window.delegatedRuns')).to eq(2)
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # The form is being submitted: a queued save would write a buffer the post save leaves behind. They are
  # dropped, their failure handlers run.
  it 'drops the saves queued behind a save the fallback wait aborted' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Queued after the hold ended'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 300;
      window.queuedFailures = 0;
      #{keep_page_js}
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, false, function () { window.queuedFailures++; });
      $('#form-post').submit();
    JS

    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_no_css('#cama_custom_loading', wait: 5)
    # The abort's answer ran to its end: a queued save sent from it would have been made by now.
    wait_for_draft_answers(1)
    expect(page.evaluate_script('window.queuedFailures')).to eq(1)
    expect(intercepted_draft_requests).to eq(1)
  end

  # A dropped save's handler that throws must not stop the ones behind it.
  it 'runs every failure handler of the saves dropped behind an aborted save when one throws' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Queued handlers after the hold ended'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 300;
      window.queuedFailures = 0;
      #{keep_page_js}
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, false, function () { throw new Error('handler failed'); });
      App_post.save_draft_ajax(null, false, function () { window.queuedFailures++; });
      $('#form-post').submit();
    JS

    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_no_css('#cama_custom_loading', wait: 5)
    wait_for_draft_answers(1)
    expect(page.evaluate_script('window.queuedFailures')).to eq(1)
    expect(intercepted_draft_requests).to eq(1)
  end

  # A failed request sends the held submit: the post save decides for itself.
  it 'submits the post when the draft save it waited for fails' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted after a failed save'

    fail_draft_requests(200)
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    # Well within submit_wait_ms: the error handler, not the fallback timer, sends the form.
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted after a failed save', status: 'published')).to be_present
  end

  # A queued save can throw before it is sent; the held submit must not wait out submit_wait_ms for it.
  it 'sends a held submit when the save it waited for throws on its way out of the queue' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted after a queued save threw'

    delay_draft_requests(500)
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      // The first save's sync passes; the queued save's throws.
      var syncs = 0;
      $('#post_content').on('change', function () { if (++syncs == 2) throw new Error('handler failed'); });
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    # Well within submit_wait_ms: the queued save's failure, not the fallback timer, sends the form.
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted after a queued save threw', status: 'published')).to be_present
    expect(new_post_buffers).to be_empty
  end

  # A held submit is stopped before other listeners see it, so each runs once, at the dispatch.
  it 'sends a held submit without running the submit listeners again' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit listeners'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 1000;
      sessionStorage.setItem('submitListenerRuns', '0');
      $('#form-post').on('submit', function () {
        sessionStorage.setItem('submitListenerRuns', String(Number(sessionStorage.getItem('submitListenerRuns')) + 1));
      });
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 10)
    expect(page.evaluate_script("sessionStorage.getItem('submitListenerRuns')")).to eq('1')
  end

  # Queued saves run through the script's own function, so a plugin's wrapper runs once per call.
  it 'runs a plugin wrapper once for a save queued behind another' do
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script(<<~JS)
      window.wrapperRuns = 0;
      var save = App_post.save_draft_ajax;
      App_post.save_draft_ajax = function () { window.wrapperRuns++; return save.apply(this, arguments); };
      $('#post_title').val('Wrapped').trigger('keyup');
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(function () { $('body').attr('data-queued-save', 'ran'); }, false);
    JS

    expect(page).to have_css('body[data-queued-save="ran"]')
    expect(page.evaluate_script('window.wrapperRuns')).to eq(2)
  end

  # Another form can be set up while the hold waits (Back is not under the overlay): the held form is gone
  # and must not be submitted in the replacement's place, but the overlay comes down.
  it 'drops a held submit whose form was replaced while it waited' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held on a form that left'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 1000;
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
      // What loading another page in place leaves behind: the held form is gone and the script's form
      // is the next one. Submitting it would show in the URL.
      $('#form-post').remove();
      $('body').append('<form id="form-post" method="get" action="' + location.pathname + '"><input type="hidden" name="probe" value="submitted"></form>');
      $form = $('#form-post');
    JS

    sleep 1.5 # past submit_wait_ms: the hold's fallback must not send the replacement form
    expect(page).to have_current_path(new_post_path, ignore_query: false)
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to be_nil
    # The overlay the hold put up is taken down all the same: nothing else on the page would.
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # camaleon_admin_ajax submits the post form in place from a listener on the body; it must see the held
  # submit once the hold ends, with the draft id in the form.
  it 'delivers a held submit to a listener delegated from an ancestor, with the draft id' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit delegated'

    delay_draft_requests(1000)
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      window.delegatedRuns = 0;
      $('body').on('submit', 'form#form-post', function () {
        window.delegatedRuns++;
        window.delegatedDraftId = $(this).find('#post_draft_id').val();
        return false;
      });
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page.evaluate_script('window.delegatedRuns')).to eq(0)
    expect_held_submit_delivered_once
    expect(page.evaluate_script('window.delegatedDraftId')).to eq(new_post_buffers.order(:id).last.id.to_s)
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # The held submit is dispatched with its button as the submitter, so the browser sends the button's name,
  # value and formaction as it would have.
  it 'dispatches a held submit with the button that made it' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit button'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 1000;
      // The button sends the form as a query to the page itself, where the browser's own submission can be read.
      $('#form-post').append('<button type="submit" name="probe" value="from the button" formmethod="get" formaction="' + location.pathname + '">Probe</button>');
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
    JS
    click_button 'Probe'

    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_current_path(/[?&]probe=from\+the\+button(&|\z)/, url: true, wait: 5)
    expect(page).to have_current_path(%r{/posts/new\?}, url: true)
  end

  # A listener bound with addEventListener sees the dispatched submit once, with its submitter; jQuery's
  # trigger would not reach it.
  it 'delivers a held submit to a listener bound outside jQuery, with its submitter' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit native listener'

    delay_draft_requests(1000)
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      window.nativeRuns = 0;
      document.getElementById('form-post').addEventListener('submit', function (e) {
        window.nativeRuns++;
        window.nativeSubmitter = e.submitter && e.submitter.name;
        e.preventDefault();
      });
      $('#form-post').append('<button type="submit" name="probe" value="native">Probe</button>');
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
    JS
    click_button 'Probe'

    expect(page.evaluate_script('window.nativeRuns')).to eq(0)
    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_no_css('#cama_custom_loading', wait: 5)
    expect(page.evaluate_script('window.nativeRuns')).to eq(1)
    expect(page.evaluate_script('window.nativeSubmitter')).to eq('probe')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # Safari before 16 has no requestSubmit; jQuery's trigger still reaches its listeners and the default action.
  it 'sends a held submit through jQuery where requestSubmit is missing' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit without requestSubmit'

    delay_draft_requests(1000)
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      delete HTMLFormElement.prototype.requestSubmit;
      #{publishable_post_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 5)
    expect(CamaleonCms::Post.find_by(title: 'Held submit without requestSubmit', status: 'published')).to be_present
  end

  # The finished save's caller takes the overlay down; a hold still waiting for a queued save puts it back,
  # or the form is open to edits the submit then sends silently.
  it 'keeps the overlay while a held submit waits for a queued save' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held behind a queued save'

    # Every draft request is held back for a while, so the queued save is in flight for as long.
    delay_draft_requests(1500)
    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 20000;
      #{publishable_post_js}
      App_post.save_draft_ajax(function () { hideLoading(); $('body').attr('data-first-save', 'ran'); }, false);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_css('body[data-first-save="ran"]', wait: 5)
    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 10)
    expect(CamaleonCms::Post.find_by(title: 'Held behind a queued save', status: 'published')).to be_present
  end

  # Save Draft puts the overlay up and its callback leaves the page; queued behind a save whose caller took
  # the overlay down, it must run under the overlay again, or edits typed meanwhile are lost to the redirect.
  it 'keeps the overlay for a Save Draft queued behind another save' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved Draft behind another save'

    delay_draft_requests(1500)
    page.execute_script(<<~JS)
      showLoading();
      App_post.save_draft_ajax(function () { hideLoading(); $('body').attr('data-first-save', 'ran'); }, false);
      App_post.save_draft();
    JS

    expect(page).to have_css('body[data-first-save="ran"]', wait: 5)
    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_current_path(%r{/admin/post_type/#{post_type_id}/posts\z}, ignore_query: true, wait: 5)
  end

  # Preview's save is flagged the same way: drained behind a save whose callback took the overlay down, it
  # runs under the overlay until the window is sent to the draft.
  it 'keeps the overlay for a Preview queued behind another save' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Previewed behind another save'

    delay_draft_requests(1500)
    # The first save runs without an overlay of its own, so the click lands; its callback takes down the one
    # the click put up, as a callback that opened something does.
    page.execute_script(<<~JS)
      App_post.save_draft_ajax(function () { hideLoading(); $('body').attr('data-first-save', 'ran'); }, false);
    JS
    preview = window_opened_by { find('.btn-preview').click }

    expect(page).to have_css('body[data-first-save="ran"]', wait: 5)
    expect(page).to have_css('#cama_custom_loading')
    within_window(preview) do
      expect(page).to have_current_path(/draft_id=\d+\z/, url: true, wait: 10)
    end
    expect(page).to have_no_css('#cama_custom_loading')
    expect(new_post_buffers.count).to eq(1)
  end

  # A plugin's call put no overlay up and its callback takes none down: restored for it, the overlay would
  # stay for good.
  it 'leaves the overlay down for a plugin save queued behind another save' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Plugin save behind another save'

    delay_draft_requests(1500)
    page.execute_script(<<~JS)
      showLoading();
      App_post.save_draft_ajax(function () { hideLoading(); $('body').attr('data-first-save', 'ran'); }, false);
      window.save_draft(function () { $('body').attr('data-plugin-save', 'ran'); });
    JS

    # The queued save is drained inside the first save's completion, so its overlay, if any, is up by now.
    expect(page).to have_css('body[data-first-save="ran"]', wait: 5)
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('body[data-plugin-save="ran"]', wait: 5)
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # Save Draft is flagged for the overlay around its own call only: a save a change handler asks for while
  # Save Draft's editors are synced is the plugin's, and nothing of its would take the overlay down.
  it 'leaves the overlay down for a plugin save a change handler queued during Save Draft\'s save' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Plugin save from a change handler'

    # Save Draft's save is refused, which gives the editor back; the plugin's queued save is sent for real.
    answer_first_draft_request("{ error: ['the draft was refused'] }", 500)
    page.execute_script(<<~JS)
      var asked = false;
      $('#post_content').on('change', function () {
        if (asked) return;
        asked = true;
        window.save_draft(function () { $('body').attr('data-plugin-save', 'ran'); });
      });
      App_post.save_draft();
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'the draft was refused')
    expect(page).to have_css('body[data-plugin-save="ran"]', wait: 5)
    expect(page).to have_no_css('#cama_custom_loading')
    expect(new_post_buffers.count).to eq(1)
  end

  # A stalled request fails after save_timeout_ms, or Preview and Save Draft stay dead until the browser
  # gives up.
  it 'fails a draft save that has not returned after save_timeout_ms' do
    stalled = false
    calls = 0
    allow_any_instance_of(CamaleonCms::Admin::Posts::DraftsController).to receive(:create)
      .and_wrap_original do |create, *args|
      calls += 1
      next create.call(*args) unless calls == 1

      sleep 1.5
      stalled = true
      create.receiver.render json: { error: ['too late'] }
    end

    visit new_post_path
    wait_for_editor_baseline
    page.execute_script(<<~JS)
      App_post.save_timeout_ms = 500;
      $('#post_title').val('Timed out').trigger('keyup');
      App_post.save_draft_ajax(null, false, function () { $('body').attr('data-save-failed', 'ran'); });
    JS

    expect(page).to have_css('body[data-save-failed="ran"]')
    expect(page).to have_css('#cama_alert_modal', text: 'The draft could not be saved')

    page.execute_script(<<~JS)
      App_post.save_timeout_ms = 30000;
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS
    expect(page).to have_css('body[data-later-save="ran"]')
    expect(new_post_buffers.order(:id).last.title).to eq('Timed out')
    # Let the stalled request finish inside the example, where its rendering is harmless.
    wait_until { stalled }
  end

  # The timer's save fails silently: there is nothing for the user to do, and the form still differs from
  # the last save, so the next tick sends it again.
  it 'retries a failed timer save on the next tick without reporting it' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Failed on the timer'

    fail_draft_requests(100)
    autosave_tick
    wait_for_draft_answers(1)
    expect_no_alert
    expect(page).to have_no_css('#cama_custom_loading')

    autosave_tick
    wait_for_draft_answers(2)
    expect(intercepted_draft_requests).to eq(2)
  end

  # The post save would refuse the same content: the hold is dropped, its timer cleared, and the user reads
  # the refusal.
  it 'keeps the post on the form when the draft save it waited for is refused' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused during autosave'

    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 1000;
      #{publishable_post_js}
      $('#post_status').append('<option value="bogus">bogus</option>').val('bogus');
      App_post.save_draft_ajax(null, true);
      $('#form-post').submit();
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'post[status] is not a status the post editor offers')
    expect(page).to have_no_css('#cama_custom_loading')
    sleep 1.5 # past submit_wait_ms: the released hold's fallback must not send the form either
    expect(page).to have_current_path(new_post_path, ignore_query: true)
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to be_nil
  end

  # A timer call queued behind a refused save would only be refused again, with a second alert.
  it 'drops a timer call queued behind a save that is refused' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    page.execute_script(<<~JS)
      $('#post_status').append('<option value="bogus">bogus</option>').val('bogus');
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, true);
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'post[status] is not a status the post editor offers')
    wait_for_ajax
    expect(draft_saves).to eq(1)
  end

  # A refusal is decided by the content: an unchanged form would be refused every minute with the same
  # alert. A save the user asks for is always sent.
  it 'does not resend a refused form until it changes' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    page.execute_script("$('#post_status').append('<option value=\"bogus\">bogus</option>').val('bogus')")
    autosave_tick
    expect(page).to have_css('#cama_alert_modal', text: 'post[status] is not a status the post editor offers')
    wait_for_ajax
    expect(draft_saves).to eq(1)

    autosave_tick
    expect(draft_saves).to eq(1)

    page.execute_script("$('#post_status option[value=bogus]').remove()")
    fill_in 'post_title', with: 'Accepted once changed'
    autosave_tick
    wait_for_ajax
    expect(draft_saves).to eq(2)
    expect(new_post_buffers.order(:id).last.title).to eq('Accepted once changed')
  end

  # The sync runs change handlers that may write derived fields; the saved state must be read after them,
  # or the next tick sees the derived field as an edit.
  it 'records the form as it was sent, after the editors\' change handlers ran' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    page.execute_script(<<~JS)
      $('#form-post').append('<input type="hidden" id="derived_probe" name="derived_probe" value="">');
      $('#post_content').on('change', function () { $('#derived_probe').val('derived'); });
      tinymce.get('post_content').setContent('<p>Derived from</p>');
      App_post.save_draft_ajax(null, true);
    JS
    wait_for_ajax
    expect(draft_saves).to eq(1)

    autosave_tick

    expect(draft_saves).to eq(1)
  end

  # The snapshot ran on a two-second timer; an editor that came up later normalized its textarea, so an
  # untouched post was autosaved and leaving asked to confirm changes never made.
  it 'takes the baseline once the editors are ready, so an untouched post stays unchanged' do
    post = site.the_post('sample-post')
    post.update!(content: 'Plain body, not yet normalized by the editor')

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    delay_content_editor
    wait_for_editor_baseline
    expect(page).to have_css('#post_content_ifr')
    count_draft_saves

    autosave_tick

    expect(draft_saves).to eq(0)
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil
  end

  # Before the baseline there is nothing to compare with; a tick must not send the raw, unnormalized form.
  it 'sends nothing from the timer before the baseline is taken' do
    post = site.the_post('sample-post')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    count_draft_saves
    # The content editor is held back, so the baseline waits for it: the tick lands before it.
    delay_content_editor
    page.execute_script("$('#post_title').val('Edited before the baseline').trigger('keyup');")
    autosave_tick
    expect(draft_saves).to eq(0)

    wait_for_editor_baseline
    fill_in 'post_title', with: 'Edited after the baseline'
    autosave_tick
    wait_for_ajax
    expect(draft_saves).to eq(1)
  end

  # A tick while the post save's response is pending wrote a buffer the post save leaves behind, listed
  # under Drafts as a newer edit.
  it 'sends nothing from the timer once the post form was submitted' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted, then edited'
    count_draft_saves

    # A listener behind the validator's keeps the page, as a post save whose response is still to come does.
    # The editors are saved first: a jQuery-triggered submit reaches no listener of TinyMCE's, and the
    # validator reads the textarea.
    page.execute_script(<<~JS)
      #{keep_page_js}
      #{publishable_post_js}
      tinymce.triggerSave();
      $('#form-post').submit();
    JS
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to eq(1)

    fill_in 'post_title', with: 'Edited after the submit'
    autosave_tick
    expect(draft_saves).to eq(0)
    expect(new_post_buffers).to be_empty
  end

  # The prompt used to fire for an untouched post until the baseline was taken (up to ten seconds).
  it 'does not prompt to leave an untouched post before the baseline' do
    post = site.the_post('sample-post')
    post.update!(content: 'Plain body, not yet normalized by the editor')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    delay_content_editor

    wait_for_leave_prompt
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil

    wait_for_editor_baseline
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil
  end

  # The prompt used to be installed a second after the editor: an edit typed in that second left silently,
  # and a form loaded in place got the previous form's prompt meanwhile.
  it 'installs the leave prompt with the editor, before the baseline' do
    visit new_post_path
    # The editor's setup publishes window.save_draft as it runs; the prompt must be in place by then.
    wait_until { page.evaluate_script('typeof window.save_draft === "function"') }
    expect(page.evaluate_script('typeof window.onbeforeunload')).to eq('function')
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil
  end

  # The baseline absorbed an edit typed before it, so the prompt read the edit as the original and the timer
  # never sent it.
  it 'keeps prompting for an edit typed before the baseline, and autosaves it' do
    post = site.the_post('sample-post')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    count_draft_saves
    delay_content_editor
    fill_in 'post_title', with: 'Typed before the baseline'

    wait_for_leave_prompt
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')

    wait_for_editor_baseline
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
    autosave_tick
    wait_for_ajax
    expect(draft_saves).to eq(1)
    expect(CamaleonCms::Post.where(post_parent: post.id,
                                   status: 'draft_child').last.title).to eq('Typed before the baseline')
  end

  # A control elsewhere on the page that names the form is sent and compared with it, so typing in it
  # before the baseline is an edit of the form too.
  it 'keeps prompting for an edit typed before the baseline into a control outside the form that names it' do
    post = site.the_post('sample-post')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    count_draft_saves
    delay_content_editor
    page.execute_script(<<~JS)
      $('body').append('<input type="text" id="outside_probe" name="outside_probe" form="form-post" value="">');
    JS
    fill_in 'outside_probe', with: 'Typed outside before the baseline'

    wait_for_leave_prompt
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')

    wait_for_editor_baseline
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
    autosave_tick
    wait_for_ajax
    expect(draft_saves).to eq(1)
  end

  # Typing in an editor fires nothing on the form; the editor's own change event says it was edited.
  it 'prompts to leave before the baseline when the content editor was typed in' do
    post = site.the_post('sample-post')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    add_late_editor
    expect(page).to have_css('#post_content_ifr')
    wait_for_leave_prompt
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil

    within_frame('post_content_ifr') { find('body').send_keys('Typed in the editor') }

    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
    init_late_editor
    wait_for_editor_baseline
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
  end

  # TinyMCE clears the dirty flag when the editor saves into its textarea (on blur); the change event is
  # what records the edit.
  it 'keeps prompting for an edit typed in the editor before the baseline once the editor loses focus' do
    post = site.the_post('sample-post')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    count_draft_saves
    add_late_editor
    expect(page).to have_css('#post_content_ifr')
    wait_for_leave_prompt
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil

    within_frame('post_content_ifr') { find('body').send_keys('Typed, then left') }
    find_by_id('post_title').click

    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
    init_late_editor
    wait_for_editor_baseline
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
    autosave_tick
    wait_for_ajax
    expect(draft_saves).to eq(1)
    expect(CamaleonCms::Post.where(post_parent: post.id,
                                   status: 'draft_child').last.content).to include('Typed, then left')
  end

  # A baseline wait can outlive its form (another page loaded in place): it must leave the next form to its
  # own baseline and not fail on a page without a form.
  it 'leaves a form the editor was set up on later alone when the wait outlives its own' do
    post = site.the_post('sample-post')

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    page.execute_script(<<~JS)
      (function delayEditor() {
        var editor = tinymce.get('post_content');
        if (!editor) return setTimeout(delayEditor, 10);
        editor.remove();
        setTimeout(function () {
          // What opening another post in place leaves behind: the script's form is the next one.
          $form = $('<form id="form-post-next"></form>');
          tinymce.init(cama_get_tinymce_settings({ selector: '#post_content', height: '480px' }));
        }, 2000);
      })();
    JS
    expect(page).to have_css('#post_content_ifr', wait: 10)

    expect(page.evaluate_script('$form.data("hash")')).to be_nil
    expect(page.evaluate_script('$("#form-post").data("hash")')).to be_nil

    # A page without a post form: the prompt finds no form to look in, does not fail, and asks nothing
    # (no baseline was taken and nothing was touched).
    page.execute_script('$form = $();')
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil
  end

  # A save can return after another post's form was loaded in place; its draft id belongs to the form it
  # was sent from, or the next post's save would discard the wrong buffer.
  it 'writes the draft id into the form the save was sent from, not one set up later' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved for the previous form'

    delay_draft_requests(1000)
    page.execute_script(<<~JS)
      $(document).ajaxComplete(function (e, xhr, settings) {
        if (/\\/drafts(\\/|$)/.test(settings.url)) $('body').attr('data-draft-saved', 'ran');
      });
      App_post.save_draft_ajax(null, true);
      // What opening another post in place leaves behind while the save is in flight: the previous form
      // is gone from the page and the script's form is the next one, with an empty draft id of its own.
      window.previousForm = $('#form-post').detach();
      $('body').append('<form id="form-post"><input type="hidden" id="post_draft_id" name="post[draft_id]" value="">' +
        '<div class="sl-slug-edit"><a class="btn-preview" href="/next-post?draft_id="></a></div></form>');
      $form = $('#form-post');
    JS

    expect(page).to have_css('body[data-draft-saved="ran"]', wait: 5)
    buffer = new_post_buffers.order(:id).last
    expect(buffer.title).to eq('Saved for the previous form')
    expect(page.evaluate_script("window.previousForm.find('#post_draft_id').val()")).to eq(buffer.id.to_s)
    expect(page.evaluate_script("$('#form-post #post_draft_id').val()")).to eq('')
    expect(page).to have_css("#form-post .btn-preview[href='/next-post?draft_id=']", visible: :all)
  end

  # A queued save that runs after another form was loaded in place would send that form's content to this
  # post's draft. It is dropped, its failure handler run.
  it 'drops a queued save when the page loaded another form in place while it waited' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved before the next form'
    count_draft_saves

    delay_draft_requests(1000)
    page.execute_script(<<~JS)
      $(document).ajaxComplete(function (e, xhr, settings) {
        if (/\\/drafts(\\/|$)/.test(settings.url)) $('body').attr('data-draft-saved', 'ran');
      });
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(function () { window.queuedSaveRan = true; }, false, function () { window.queuedSaveDropped = true; });
      // What opening another post in place leaves behind while the saves wait: the previous form is gone
      // and the script's form is the next one, with content of its own.
      $('#form-post').detach();
      $('body').append('<form id="form-post"><input type="hidden" name="post[title]" value="The next form"></form>');
      $form = $('#form-post');
    JS

    expect(page).to have_css('body[data-draft-saved="ran"]', wait: 5)
    expect(page.evaluate_script('window.queuedSaveDropped')).to be(true)
    expect(page.evaluate_script('window.queuedSaveRan')).to be_nil
    expect(draft_saves).to eq(1)
    expect(new_post_buffers.order(:id).last.title).to eq('Saved before the next form')
  end

  # A call for a form the setup no longer owns is dropped at once, or its failure handler waits behind a
  # save that is not its own.
  it 'drops a call for a replaced form at once while a save still runs' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Replaced while saving'

    stall_draft_requests
    page.execute_script(<<~JS)
      App_post.save_draft_ajax(null, false);
      $('#form-post').detach();
      $('body').append('<form id="form-post"></form>');
      $form = $('#form-post');
      App_post.save_draft_ajax(null, false, function () { window.laterCallDropped = true; });
    JS

    expect(page.evaluate_script('window.laterCallDropped')).to be(true)
  end

  # A translated field is edited through its per-language copies; the comparison reads those.
  it 'autosaves an edit to a second language of a translated field' do
    site.set_meta('languages_site', %w[en es])
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    autosave_tick
    expect(draft_saves).to eq(0)

    page.execute_script(<<~JS)
      $('.title-post.translate-item[data-translation_l="es"]').val('Título en español').trigger('change');
      var content_es = $('.tinymce_textarea.translate-item[data-translation_l="es"]').attr('id');
      tinymce.get(content_es).setContent('<p>Cuerpo</p>');
    JS
    autosave_tick
    wait_for_ajax
    expect(draft_saves).to eq(1)

    buffer = new_post_buffers.order(:id).last
    expect(buffer.title).to include('<!--:es-->Título en español<!--:-->')
    expect(buffer.content).to include('<!--:es--><p>Cuerpo</p><!--:-->')

    autosave_tick
    expect(draft_saves).to eq(1)
  end

  # A translated form has one Preview link per language.
  it 'points every Preview link of a translated form at the draft' do
    site.set_meta('languages_site', %w[en es])
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script(<<~JS)
      $('.title-post.translate-item[data-translation_l="en"]').val('English title').trigger('change');
      $('.title-post.translate-item[data-translation_l="es"]').val('Título en español').trigger('change');
    JS
    autosave_tick
    wait_for_ajax

    buffer = new_post_buffers.order(:id).last
    expect(page).to have_css('#form-post .btn-preview', count: 2, visible: :all)
    expect(page).to have_css("#form-post .btn-preview[href$='draft_id=#{buffer.id}']", count: 2, visible: :all)
  end

  # A copy composes the hidden original on change, which fires on blur: a copy still being typed in was sent
  # stale and, since the comparison reads the copies, never resent. A send recomposes the originals.
  it 'sends a translated field typed in since its copy last lost focus' do
    site.set_meta('languages_site', %w[en es])
    visit new_post_path
    wait_for_editor_baseline

    # The value as typing leaves it before the field loses focus: no change event yet.
    page.execute_script(<<~JS)
      $('.title-post.translate-item[data-translation_l="es"]').val('Aún escribiendo').trigger('keyup');
    JS
    autosave_tick
    wait_for_ajax

    expect(new_post_buffers.order(:id).last.title).to include('<!--:es-->Aún escribiendo<!--:-->')
  end

  # The comparison used to write each editor back into its textarea, rewriting content a plugin had put
  # there (camaleon_editor's grid export, with rgb() colors).
  it 'leaves the editors\' textareas alone when it compares the form' do
    visit new_post_path
    wait_for_editor_baseline
    exported = '<p style="color: rgb(255, 204, 0);">Body</p>'

    page.execute_script(<<~JS)
      tinymce.get('post_content').setContent(#{exported.to_json});
      $('#post_content').val(#{exported.to_json});
      window.onbeforeunload();
    JS

    expect(page.evaluate_script("$('#post_content').val()")).to eq(exported)
  end

  # An editor a plugin puts elsewhere on the page (a modal) read as an edit of the post.
  it 'ignores an editor outside the post form when it compares the form' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    page.execute_script(<<~JS)
      $('body').append('<textarea id="outside_editor"></textarea>');
      tinymce.init(cama_get_tinymce_settings({ selector: '#outside_editor', height: 100 }));
    JS
    expect(page).to have_css('#outside_editor_ifr')
    page.execute_script("tinymce.get('outside_editor').setContent('<p>Not the post</p>');")
    autosave_tick

    expect(draft_saves).to eq(0)
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil
  end

  # A field with id `constructor` was taken for an editor (`in` matched the inherited name) and dropped from
  # the comparison.
  it 'autosaves an edit to a field whose id is an inherited object property name' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    # A save the user asks for always sends, and records the form with the new field in it.
    page.execute_script(<<~JS)
      $('#form-post').append('<input type="hidden" id="constructor" name="constructor_probe" value="">');
      App_post.save_draft_ajax(null, false);
    JS
    wait_for_ajax
    expect(draft_saves).to eq(1)

    page.execute_script("$('#constructor').val('edited');")
    autosave_tick

    expect(draft_saves).to eq(2)
  end

  # A control with form="form-post" outside the form is sent by the browser; the comparison walked the
  # form's descendants only, so an edit to it was never autosaved.
  it 'autosaves an edit to a control outside the form that names it' do
    visit new_post_path
    wait_for_editor_baseline
    count_draft_saves

    # A save the user asks for always sends, and records the form with the new control in it.
    page.execute_script(<<~JS)
      $('body').append('<input type="hidden" id="outside_probe" name="outside_probe" form="form-post" value="">');
      App_post.save_draft_ajax(null, false);
    JS
    wait_for_ajax
    expect(draft_saves).to eq(1)

    page.execute_script("$('#outside_probe').val('edited');")
    autosave_tick

    expect(draft_saves).to eq(2)
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
  end

  # jQuery serializes a fieldset's controls a second time: an editor's stale textarea inside one read as an
  # edit once the blur handler saved into it.
  it 'reads an untouched post as unchanged when its editor sits in a fieldset' do
    post = site.the_post('sample-post')
    post.update!(content: 'Plain body, not yet normalized by the editor')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait_for_editor_setup
    # The editor is held back so the textarea can be wrapped before the baseline is taken.
    delay_content_editor
    page.execute_script("$('#post_content').wrap('<fieldset></fieldset>');")
    wait_for_editor_baseline
    count_draft_saves

    page.execute_script('tinymce.triggerSave();')
    autosave_tick

    expect(draft_saves).to eq(0)
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil
  end

  # The comparison reads the editors themselves.
  it 'autosaves an edit made in the editor alone' do
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script("tinymce.get('post_content').setContent('<p>Typed in the editor</p>');")
    autosave_tick
    wait_for_ajax

    expect(new_post_buffers.order(:id).last.content).to include('<p>Typed in the editor</p>')
  end

  # The window is opened in the click; a popup blocker would refuse one opened from the async callback.
  it 'opens the preview of the saved draft in a new window' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Previewed title'

    preview = window_opened_by { find('.btn-preview').click }

    within_window(preview) do
      # The URL first: the window is sent from about:blank to the draft once the save returns, and a
      # text query that spans that navigation holds nodes of the document being replaced.
      expect(page).to have_current_path(/draft_id=\d+\z/, url: true)
      expect(page).to have_current_path(/draft_id=#{new_post_buffers.order(:id).last.id}\z/, url: true)
      expect(page).to have_text('Previewed title')
    end
  end

  # A Preview clicked during a save waits for that save's draft id, and a new post gets no second buffer.
  it 'previews the draft when Preview is clicked while an autosave is in flight' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Queued preview title'

    # The first draft request is held back for a while, so the click lands while it is in flight.
    intercept_draft_requests(<<~HANDLER)
      (function () {
        var held = false;
        return function (options, send) {
          if (held) return send();
          held = true;
          setTimeout(send, 1500);
          return $.Deferred().promise();
        };
      })()
    HANDLER
    autosave_tick
    preview = window_opened_by { find('.btn-preview').click }

    within_window(preview) do
      # The window leaves about:blank once both saves are through. Its URL is read first: a text query
      # that spans the navigation holds nodes of the document being replaced, which Chrome refuses.
      expect(page).to have_current_path(/draft_id=\d+\z/, url: true, wait: 10)
      expect(page).to have_current_path(/draft_id=#{new_post_buffers.order(:id).last.id}\z/, url: true)
      expect(page).to have_text('Queued preview title')
    end
    expect(new_post_buffers.count).to eq(1)
  end

  # A refused save gives the window nothing to show.
  it 'closes the preview window and frees the editor when the draft save is refused' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused preview title'

    refuse_draft_requests('the preview draft was refused', 500)
    preview = window_opened_by { find('.btn-preview').click }

    expect(page).to have_css('#cama_alert_modal', text: 'the preview draft was refused')
    expect(preview).to be_closed
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # A failed request gives the window nothing to show either, and the user asked for the save.
  it 'closes the preview window and reports the failure when the draft request fails' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Failed preview title'

    fail_draft_requests(500)
    preview = window_opened_by { find('.btn-preview').click }

    expect(page).to have_css('#cama_alert_modal', text: 'The draft could not be saved')
    expect(preview).to be_closed
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # The link's default action is prevented before the save: if the save throws, the link (naming no draft)
  # must not open in a new tab.
  it 'opens no window when the Preview save could not be sent' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Unsent preview title'

    intercept_draft_requests("function () { throw new Error('refused to send'); }")

    expect { find('.btn-preview').click }.not_to(change { page.windows.size })
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # A submit the validator lets through unvalidated (cancelSubmit: Cancel, formnovalidate, recover-draft)
  # used to be validated by the hold handler, painting errors and skipping the submitted mark.
  it 'lets a submit the validator was told to skip through without validating it' do
    visit new_post_path
    wait_for_editor_baseline

    # The title is empty, so validation would refuse. A listener behind the validator's keeps the page.
    page.execute_script(<<~JS)
      #{keep_page_js}
      $('#form-post').data('validator').cancelSubmit = true;
      $('#form-post').submit();
    JS

    expect(page).to have_no_css('#form-post label.error', visible: :all)
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to eq(1)
  end

  # The validator resets cancelSubmit in its own submit handler, which a held submit never reaches: after a
  # refused save dropped such a hold, the next submit went through unvalidated.
  it 'validates the submit after a held one the validator was told to skip was dropped' do
    visit new_post_path
    wait_for_editor_baseline

    # The draft save is held back until the example refuses it. The title is empty throughout: the first
    # submit is one the validator was told to skip, the second is not. A listener behind the validator's
    # keeps the page either way.
    intercept_draft_requests('function (options) { window.draftRequest = options; return $.Deferred().promise(); }')
    page.execute_script(<<~JS)
      #{keep_page_js}
      App_post.save_draft_ajax(null, false);
      $('#form-post').data('validator').cancelSubmit = true;
      $('#form-post').submit();
    JS
    expect(page).to have_css('#cama_custom_loading')

    page.execute_script("window.draftRequest.success({ error: ['the draft was refused'] });")
    expect(page).to have_css('#cama_alert_modal', text: 'the draft was refused')
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to be_nil

    page.execute_script("$('#form-post').submit();")

    expect(page).to have_css('#form-post label.error', visible: :all)
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to be_nil
  end

  it 'saves the draft and returns to the post list on Save Draft' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved draft title'

    click_link 'Save Draft'

    expect(page).to have_current_path(%r{/admin/post_type/#{post_type_id}/posts\z}, ignore_query: true)
    expect(new_post_buffers.order(:id).last.title).to eq('Saved draft title')
  end

  # The notice travels in the query string; a translation with `&`, `#` or `+` was cut at that character.
  it 'sends the Save Draft notice encoded in the redirect' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Encoded notice title'

    page.execute_script("I18n_data.msg.draft = 'Saved & done';")
    click_link 'Save Draft'

    expect(page).to have_current_path(/flash\[notice\]=Saved%20%26%20done(&|\z)/, url: true)
  end

  # Save Draft's callback marks the form submitted and leaves; run for a replaced form, it would silence the
  # next form's prompt and take its page away.
  it 'stays on the form the page loaded in place when Save Draft returns for the one before it' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved draft before the next form'

    delay_draft_requests(1000)
    page.execute_script(<<~JS)
      App_post.save_draft();
      // What opening another post in place leaves behind while the save runs: the previous form is gone
      // and the script's form is the next one.
      $('#form-post').detach();
      $('body').append('<form id="form-post"><input type="hidden" name="post[title]" value="The next form"></form>');
      $form = $('#form-post');
    JS

    wait_until { new_post_buffers.exists? }
    sleep 1 # long enough for a callback that leaves the page to have left it
    expect(page).to have_current_path(new_post_path, ignore_query: true)
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to be_nil
    expect(new_post_buffers.order(:id).last.title).to eq('Saved draft before the next form')
  end

  # A refusal or failure can return after another page was loaded in place: shown there, it names the post
  # it is about, with the title as text.
  it 'names the post in a refusal shown over a page loaded in place' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused <b>before</b> the next page'

    refuse_draft_requests('the draft was refused', 1000)
    page.execute_script(<<~JS)
      App_post.save_draft();
      // What opening another page in place leaves behind while the save runs.
      $('#form-post').detach();
      $('body').append('<form id="form-post"><input type="hidden" name="post[title]" value="The next form"></form>');
      $form = $('#form-post');
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'Refused <b>before</b> the next page: the draft was refused')
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # A page with no post form loaded in place (the list, via Back) leaves the script's form the one that left
  # the page: the alert names the post all the same, and a failure as a refusal does.
  it 'names the post in a failure shown over a page without a form loaded in place' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Failed before the list'

    fail_draft_requests(1000)
    page.execute_script(<<~JS)
      App_post.save_draft();
      // What opening the post list in place leaves behind while the save runs: the form is gone, and no
      // form took its place.
      $('#form-post').detach();
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'Failed before the list: The draft could not be saved')
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # The core refuses with a list; a decorated drafts action may send one message.
  it 'shows a refusal sent as one message and frees the editor' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused as one message'
    intercept_draft_requests(<<~HANDLER)
      function (options) {
        setTimeout(function () { options.success({ error: 'the draft was refused as one message' }); }, 200);
        return $.Deferred().promise();
      }
    HANDLER

    page.execute_script('App_post.save_draft();')

    expect(page).to have_css('#cama_alert_modal', text: 'the draft was refused as one message')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # A decorated action may send the model's errors keyed by field; rendered as text they read
  # "[object Object]".
  it 'shows a refusal sent as messages keyed by field' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused by field'
    intercept_draft_requests(<<~HANDLER)
      function (options) {
        setTimeout(function () { options.success({ error: { title: ['is too long'], slug: 'is taken' } }); }, 200);
        return $.Deferred().promise();
      }
    HANDLER

    page.execute_script('App_post.save_draft();')

    expect(page).to have_css('#cama_alert_modal', text: 'title is too long, slug is taken')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # `{ error: [] }` (a model callback aborted the save without an error) showed an empty alert, dropped a
  # held submit and silenced the timer. It is a failed request: reported, and a held submit goes out.
  it 'fails a refusal that names no message' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused without a message'
    answer_first_draft_request('{ error: [] }')

    page.execute_script('App_post.save_draft();')

    expect(page).to have_css('#cama_alert_modal', text: 'The draft could not be saved')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)

    page.execute_script("App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);")
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # A decorated action may answer `{}` or `null`: there is no draft to name, so the save fails.
  it 'fails a draft response that names no draft' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Answered without a draft'
    answer_first_draft_request('{}')

    page.execute_script('App_post.save_draft();')

    expect(page).to have_css('#cama_alert_modal', text: 'The draft could not be saved')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)

    page.execute_script("App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);")
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # `{ draft: {} }` taken as a success wrote `undefined` into the Preview links and started the next save
  # from no draft, so a new post got a second buffer.
  it 'fails a draft response whose draft names no id' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Answered with a draft without an id'
    answer_first_draft_request('{ draft: {} }')

    page.execute_script('App_post.save_draft();')

    expect(page).to have_css('#cama_alert_modal', text: 'The draft could not be saved')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
    expect(page.evaluate_script('$("#form-post .btn-preview").attr("href")')).not_to include('undefined')

    page.execute_script("App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);")
    expect(page).to have_css('body[data-later-save="ran"]')
    expect(new_post_buffers.count).to eq(1)
  end

  # Save Draft holds the form under the overlay; a refused save must give it back.
  it 'keeps the editor usable when Save Draft is refused' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused draft title'

    # The save is held for a while so the overlay can be seen, then refused as the server would.
    refuse_draft_requests('the draft was refused', 1000)
    page.execute_script(<<~JS)
      App_post.save_draft();
    JS

    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_css('#cama_alert_modal', text: 'the draft was refused')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end
end
