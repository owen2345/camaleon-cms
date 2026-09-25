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

  # The held submit runs the submit's default action only: validation and every submit listener already
  # ran when the submit was held, so a listener that asks a question or serializes the form is not run
  # a second time when the hold is released.
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
      expect(page).to have_text('Previewed title')
      expect(page).to have_current_path(/draft_id=#{new_post_buffers.order(:id).last.id}\z/, url: true)
    end
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
