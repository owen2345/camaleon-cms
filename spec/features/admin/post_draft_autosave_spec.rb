# frozen_string_literal: true

# The post editor autosaves a draft buffer every minute while the form differs from its last saved
# state. `App_post.save_draft_ajax(null, true)` is exactly what the minute timer runs, so these
# examples call it directly instead of waiting for the timer.
describe 'Post editor draft autosave', :js do
  let!(:site) { CamaleonCms::Site.first.decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let(:new_post_path) { "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new" }

  def new_post_buffers
    CamaleonCms::Post.where(status: 'draft_child', post_parent: nil)
  end

  # Waits until the editor has taken the form's baseline snapshot, which the autosave compares against.
  # The editor stops waiting for its TinyMCE editors after ten seconds, so the bound is above that.
  def wait_for_editor_baseline
    expect(page).to have_css('#form-post .sl-slug-edit', visible: :all)
    Timeout.timeout(15) do
      sleep(0.1) until page.evaluate_script('$("#form-post").data("hash") !== undefined')
    end
  end

  # Counts the draft requests the editor sends from here on (sync or async, ajaxSend fires on the call).
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

  def autosave_tick
    page.execute_script('App_post.save_draft_ajax(null, true)')
  end

  before { admin_sign_in }

  # The permalink widget writes `?draft_id=` into the Preview link when the title produces a slug,
  # which on a new post is before any draft exists. An autosave then created the draft but left the
  # link empty, so opening Preview in a new tab (middle-click, copy link) rendered no draft.
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

  # The minute timer compared the form with the snapshot taken at load and never refreshed it, so
  # after the first edit it re-sent the unchanged form every minute.
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

  # Saves no longer block the page, so a tick can start while an earlier save of a new post is still
  # in flight; the second one must wait for the first draft's id instead of creating another buffer.
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

  # A queued timer call finds nothing new to send once the save ahead of it has run, and returns
  # without a request; the saves queued behind it must still run.
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

  # jQuery skips an ajax call's `complete` handler when its success handler throws, so a failing
  # callback must not leave the save lock held: later saves would queue forever and a submit
  # would wait for them forever.
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

  # $.ajax can throw before sending (a plugin's wrapper, a prefilter). The lock it would have released
  # must not stay held, or every later save queues forever and every submit waits under the overlay; and
  # the caller's failure handler runs, since it is what takes down the overlay or window the caller opened.
  it 'runs later saves and the failure handler after $.ajax threw before sending one' do
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (/\\/drafts(\\/|$)/.test(options.url)) throw new Error('refused to send');
        return ajax.apply(this, arguments);
      };
      $('#post_title').val('Thrown before sending').trigger('keyup');
      try {
        App_post.save_draft_ajax(null, false, function () { window.sendFailed = true; });
      } catch (e) { window.sendThrew = e.message; }
      $.ajax = ajax;
      App_post.save_draft_ajax(function () { $('body').attr('data-later-save', 'ran'); }, false);
    JS

    expect(page.evaluate_script('window.sendThrew')).to eq('refused to send')
    expect(page.evaluate_script('window.sendFailed')).to be(true)
    expect(page).to have_css('body[data-later-save="ran"]')
  end

  # The editors are synced into their textareas before a draft is serialized, and a change handler on one
  # may ask for a save of its own. That call has to queue behind the one being prepared, not run beside
  # it: on a new post, two concurrent creates make two buffers.
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

  # A save can throw before it is sent from the editors' sync as well as from $.ajax: a change handler
  # that fails. The lock is released and the failure handler runs either way.
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

  # Submitting the post while an autosave of the new post is in flight used to post an empty draft id,
  # so the buffer that save created was never discarded. The submit now waits for the draft id.
  it 'discards the new post buffer when the post is submitted during an autosave' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted during autosave'

    page.execute_script(<<~JS)
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(null, true);
      $('#form-post').submit();
    JS

    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted during autosave', status: 'published')).to be_present
    expect(new_post_buffers).to be_empty
  end

  # A draft save that never returns must not block the post: the held submit shows the loading overlay
  # and is sent anyway once App_post.submit_wait_ms has passed.
  it 'submits the post after a while when the draft save in flight never returns' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted during a stalled save'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (/\\/drafts(\\/|$)/.test(options.url)) return $.Deferred().promise();
        return ajax.apply(this, arguments);
      };
      App_post.submit_wait_ms = 2000;
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_css('#cama_custom_loading')
    # The held submit is sent only once submit_wait_ms has passed, beyond Capybara's default wait.
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 10)
    expect(CamaleonCms::Post.find_by(title: 'Submitted during a stalled save', status: 'published')).to be_present
  end

  # A draft request that fails (here the transport reports an error) releases the save lock and sends
  # the held submit: the post save decides for itself, and the buffer, if any, is left behind.
  it 'submits the post when the draft save it waited for fails' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted after a failed save'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        setTimeout(function () { options.error({}, 'error', ''); }, 200);
        return $.Deferred().promise();
      };
      App_post.submit_wait_ms = 20000;
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    # Well within submit_wait_ms: the error handler, not the fallback timer, sends the form.
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted after a failed save', status: 'published')).to be_present
  end

  # The saves queued behind a finished one are run from its completion, and one of them can throw before
  # it is sent. The held submit must not wait out submit_wait_ms for a save that is not running.
  it 'sends a held submit when the save it waited for throws on its way out of the queue' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Submitted after a queued save threw'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        var self = this, args = arguments;
        setTimeout(function () { ajax.apply(self, args); }, 500);
        return $.Deferred().promise();
      };
      App_post.submit_wait_ms = 20000;
      // The first save's sync passes; the queued save's throws.
      var syncs = 0;
      $('#post_content').on('change', function () { if (++syncs == 2) throw new Error('handler failed'); });
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(null, false);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    # Well within submit_wait_ms: the queued save's failure, not the fallback timer, sends the form.
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true)
    expect(CamaleonCms::Post.find_by(title: 'Submitted after a queued save threw', status: 'published')).to be_present
    expect(new_post_buffers).to be_empty
  end

  # A submit is held before validation and any other listener see it, and dispatched again when the hold
  # ends, so a listener that asks a question or serializes the form runs once, then, not twice.
  it 'sends a held submit without running the submit listeners again' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit listeners'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (/\\/drafts(\\/|$)/.test(options.url)) return $.Deferred().promise();
        return ajax.apply(this, arguments);
      };
      App_post.submit_wait_ms = 1000;
      sessionStorage.setItem('submitListenerRuns', '0');
      $('#form-post').on('submit', function () {
        sessionStorage.setItem('submitListenerRuns', String(Number(sessionStorage.getItem('submitListenerRuns')) + 1));
      });
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 10)
    expect(page.evaluate_script("sessionStorage.getItem('submitListenerRuns')")).to eq('1')
  end

  # A save queued behind a running one is run again from the queue. It goes through the function the
  # script owns, not through App_post.save_draft_ajax, so a wrapper a plugin installed there runs once
  # per call, when the call was made, and not a second time when the queue is drained.
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

  # A held submit is sent to the form it was held on. With pages loading in place, another form can be
  # set up while the hold waits (the browser's Back button is not under the overlay): the script's form
  # is then that one, and it must not be submitted in the held form's place.
  it 'drops a held submit whose form was replaced while it waited' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held on a form that left'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (/\\/drafts(\\/|$)/.test(options.url)) return $.Deferred().promise();
        return ajax.apply(this, arguments);
      };
      App_post.submit_wait_ms = 1000;
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
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
  end

  # A listener delegated from an ancestor (camaleon_admin_ajax submits the post form in place from one
  # bound on the body) sees the held submit too, once the hold ends, with the draft id in the form; it
  # may then take the submit over, as that plugin does.
  it 'delivers a held submit to a listener delegated from an ancestor, with the draft id' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held submit delegated'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        var self = this, args = arguments;
        setTimeout(function () { ajax.apply(self, args); }, 1000);
        return $.Deferred().promise();
      };
      App_post.submit_wait_ms = 20000;
      window.delegatedRuns = 0;
      $('body').on('submit', 'form#form-post', function () {
        window.delegatedRuns++;
        window.delegatedDraftId = $(this).find('#post_draft_id').val();
        return false;
      });
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page.evaluate_script('window.delegatedRuns')).to eq(0)
    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_no_css('#cama_custom_loading', wait: 5)
    expect(page.evaluate_script('window.delegatedRuns')).to eq(1)
    expect(page.evaluate_script('window.delegatedDraftId')).to eq(new_post_buffers.order(:id).last.id.to_s)
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # A held submit also waits for the saves queued behind the one it was held on. The finished save's
  # caller takes the overlay down (Preview, Save Draft do), so the hold has to put it back while the
  # queued save runs, or the form is open to edits that the submit then sends without a word.
  it 'keeps the overlay while a held submit waits for a queued save' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Held behind a queued save'

    # Every draft request is held back for a while, so the queued save is in flight for as long.
    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        var self = this, args = arguments;
        setTimeout(function () { ajax.apply(self, args); }, 1500);
        return $.Deferred().promise();
      };
      App_post.submit_wait_ms = 20000;
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
      App_post.save_draft_ajax(function () { hideLoading(); $('body').attr('data-first-save', 'ran'); }, false);
      App_post.save_draft_ajax(null, false);
      $('#form-post').submit();
    JS

    expect(page).to have_css('body[data-first-save="ran"]', wait: 5)
    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_current_path(%r{/posts/\d+/edit\z}, ignore_query: true, wait: 10)
    expect(CamaleonCms::Post.find_by(title: 'Held behind a queued save', status: 'published')).to be_present
  end

  # A draft request that has not returned after App_post.save_timeout_ms is taken as failed: the lock is
  # released, the caller's failure handler runs and the failure is reported, so a stalled server cannot
  # keep Preview and Save Draft dead until the browser gives up on the request.
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
    Timeout.timeout(5) { sleep(0.1) until stalled }
  end

  # A refused draft save (here a status the editor does not offer, refused for every role) must not
  # send the held submit: the post save would refuse the same content, and the user has to read the
  # refusal to fix it. The hold is released and its fallback timer cleared.
  it 'keeps the post on the form when the draft save it waited for is refused' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused during autosave'

    page.execute_script(<<~JS)
      App_post.submit_wait_ms = 1000;
      tinymce.get('post_content').setContent('Body');
      $("#form-post input[name='categories[]']:first").prop("checked", true);
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

  # A timer call queued behind a save that ends refused finds the same form the refusal named: sending
  # it would only be refused again, with a second alert on the heels of the first. It is dropped; the
  # next tick retries once the user has had a minute to act on the refusal.
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

  # A send runs each editor's textarea change handlers (sync_editors) after the form was compared. A
  # handler that writes a derived field changes the form between the comparison and the request, so
  # the saved state must be read after it ran, or the next tick sees the derived field as an edit.
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

  # The load snapshot was taken on a two-second timer. An editor that came up later rewrote its
  # textarea in TinyMCE's normalized form, so an untouched post read as edited: the timer autosaved
  # it and leaving the page asked to confirm discarding changes that were never made.
  it 'takes the baseline once the editors are ready, so an untouched post stays unchanged' do
    post = site.the_post('sample-post')
    post.update!(content: 'Plain body, not yet normalized by the editor')

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    page.execute_script(<<~JS)
      (function delayEditor() {
        var editor = tinymce.get('post_content');
        if (!editor) return setTimeout(delayEditor, 10);
        editor.remove();
        setTimeout(function () {
          tinymce.init(cama_get_tinymce_settings({ selector: '#post_content', height: '480px' }));
        }, 3000);
      })();
    JS
    wait_for_editor_baseline
    expect(page).to have_css('#post_content_ifr')
    count_draft_saves

    autosave_tick

    expect(draft_saves).to eq(0)
    expect(page.evaluate_script('window.onbeforeunload()')).to be_nil
  end

  # Admin pages load in place, so a baseline still waiting for an editor when the user opens another
  # page outlives its form: by the time the editor comes up (or the wait gives up) the script's form is
  # the next page's, which takes a baseline of its own, and the old wait must leave it alone and must not
  # fail on a page without a post form.
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

    # A page without a post form: the comparison finds no form to look in, and does not fail.
    page.execute_script('$form = $();')
    expect(page.evaluate_script('typeof window.onbeforeunload()')).to eq('string')
  end

  # A save is asynchronous, so with pages loading in place it can return after the editor was set up
  # on another post's form. The draft id it returns belongs to the post it was sent for: written into
  # the next form, that post's save would discard the buffer named by post[draft_id], and its Preview
  # link would open the wrong draft.
  it 'writes the draft id into the form the save was sent from, not one set up later' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved for the previous form'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        var self = this, args = arguments;
        setTimeout(function () { ajax.apply(self, args); }, 1000);
        return $.Deferred().promise();
      };
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

  # A save queued behind a running one is run when that one returns, against the script's form, which by
  # then can be another post's (the page loaded it in place while the queue waited). Serializing that form
  # sent the other post's content to this post's draft. The queued save is dropped instead, its failure
  # handler run, since it is what takes down the window or overlay the caller opened.
  it 'drops a queued save when the page loaded another form in place while it waited' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Saved before the next form'
    count_draft_saves

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        var self = this, args = arguments;
        setTimeout(function () { ajax.apply(self, args); }, 1000);
        return $.Deferred().promise();
      };
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

  # A translated field is edited through its per-language copies, which the comparison reads; the hidden
  # original they compose is left out. The content's copies are the editors, matched by the copy's id.
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

  # Comparing the form is a read. It used to write each editor's content back into its textarea, in
  # TinyMCE's serialization, so content a plugin had put into the textarea itself (camaleon_editor's
  # grid export, with its colors as rgb()) read back rewritten whenever the snapshot landed after it.
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

  # Only the post form's editors are the post's content. An editor a plugin puts elsewhere on the page
  # (a modal) must not read as an edit of the post: that autosaved an untouched post every minute and
  # asked to confirm leaving a form that had not changed.
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

  # The fields are matched against the editors read by id. A field whose id is a name every object
  # inherits (`constructor`) was taken for an editor and dropped from the comparison, so an edit to it
  # was never autosaved.
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

  # The comparison reads the editors themselves, and a save sends what they hold.
  it 'autosaves an edit made in the editor alone' do
    visit new_post_path
    wait_for_editor_baseline

    page.execute_script("tinymce.get('post_content').setContent('<p>Typed in the editor</p>');")
    autosave_tick
    wait_for_ajax

    expect(new_post_buffers.order(:id).last.content).to include('<p>Typed in the editor</p>')
  end

  # The Preview click saves the draft before opening it. The save is asynchronous now, so the window
  # is opened inside the click (a popup blocker would refuse one opened from the save's callback).
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

  # A Preview clicked while a save is in flight waits for that save's draft id: the window opened in
  # the click shows the draft once both saves are through, and a new post gets no second buffer.
  it 'previews the draft when Preview is clicked while an autosave is in flight' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Queued preview title'

    # The first draft request is held back for a while, so the click lands while it is in flight.
    page.execute_script(<<~JS)
      var ajax = $.ajax, held = false;
      $.ajax = function (options) {
        if (held || !/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        held = true;
        var self = this, args = arguments;
        setTimeout(function () { ajax.apply(self, args); }, 1500);
        return $.Deferred().promise();
      };
      App_post.save_draft_ajax(null, true);
    JS
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

  # A refused save gives the window Preview opened in the click no draft to show: the window is closed
  # again, the overlay taken down and the refusal shown.
  it 'closes the preview window and frees the editor when the draft save is refused' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused preview title'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        setTimeout(function () { options.success({ error: ['the preview draft was refused'] }); }, 500);
        return $.Deferred().promise();
      };
    JS
    preview = window_opened_by { find('.btn-preview').click }

    expect(page).to have_css('#cama_alert_modal', text: 'the preview draft was refused')
    expect(preview).to be_closed
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end

  # The click's default action, following the link into a new tab, is prevented before the save is
  # asked for: when the save throws before sending (a plugin's wrapper), the window opened in the click
  # is closed again, and the link, which names no draft yet, must not open a preview of nothing.
  it 'opens no window when the Preview save could not be sent' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Unsent preview title'

    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (/\\/drafts(\\/|$)/.test(options.url)) throw new Error('refused to send');
        return ajax.apply(this, arguments);
      };
    JS

    expect { find('.btn-preview').click }.not_to(change { page.windows.size })
    expect(page).to have_no_css('#cama_custom_loading')
  end

  # The submit handler runs the validator first, so a held submit is a valid one. A submit the validator
  # was told to let through (cancelSubmit: a Cancel or formnovalidate submit button, and the recover-draft
  # path, which recovers a buffer whatever it holds) must be let through the same way: validating it
  # painted errors under the required title and skipped the submitted mark.
  it 'lets a submit the validator was told to skip through without validating it' do
    visit new_post_path
    wait_for_editor_baseline

    # The title is empty, so validation would refuse. A listener behind the validator's keeps the page.
    page.execute_script(<<~JS)
      $('body').on('submit', 'form#form-post', function () { return false; });
      $('#form-post').data('validator').cancelSubmit = true;
      $('#form-post').submit();
    JS

    expect(page).to have_no_css('#form-post label.error', visible: :all)
    expect(page.evaluate_script('$("#form-post").data("submitted")')).to eq(1)
  end

  # The validator's own submit handler is what resets cancelSubmit, and a held submit never reaches it. When
  # the hold was dropped on a refused save, cancelSubmit stayed set, so the next submit, an ordinary one,
  # went through unvalidated: the hold handler skipped valid() and the validator let it pass.
  it 'validates the submit after a held one the validator was told to skip was dropped' do
    visit new_post_path
    wait_for_editor_baseline

    # The draft save is held back until the example refuses it. The title is empty throughout: the first
    # submit is one the validator was told to skip, the second is not. A listener behind the validator's
    # keeps the page either way.
    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        window.draftRequest = options;
        return $.Deferred().promise();
      };
      $('body').on('submit', 'form#form-post', function () { return false; });
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

  # Save Draft holds the form under the loading overlay while its save runs, since its callback leaves
  # the page; a refused save must give the form back with the refusal shown.
  it 'keeps the editor usable when Save Draft is refused' do
    visit new_post_path
    wait_for_editor_baseline
    fill_in 'post_title', with: 'Refused draft title'

    # The save is held for a while so the overlay can be seen, then refused as the server would.
    page.execute_script(<<~JS)
      var ajax = $.ajax;
      $.ajax = function (options) {
        if (!/\\/drafts(\\/|$)/.test(options.url)) return ajax.apply(this, arguments);
        setTimeout(function () { options.success({ error: ['the draft was refused'] }); }, 1000);
        return $.Deferred().promise();
      };
      App_post.save_draft();
    JS

    expect(page).to have_css('#cama_custom_loading')
    expect(page).to have_css('#cama_alert_modal', text: 'the draft was refused')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_current_path(new_post_path, ignore_query: true)
  end
end
