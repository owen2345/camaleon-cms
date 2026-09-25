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
  def wait_for_editor_baseline
    expect(page).to have_css('#form-post .sl-slug-edit', visible: :all)
    Timeout.timeout(Capybara.default_max_wait_time * 2) do
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
end
