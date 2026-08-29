# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Posts workflows for Admin', :js do
  let(:post) { site.the_post('sample-post').decorate }
  let(:post_type_id) { site.post_types.where(slug: :post).pick(:id) }
  let!(:site) { CamaleonCms::Site.first.decorate }

  it 'Creates a new post' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new"
    wait(2)

    within('#form-post') do
      fill_in 'post_title', with: 'Test Title'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet.")')
      page.execute_script('$("#form-post input[name=\'categories[]\']:first").prop("checked", true)')
      wait(2)

      fill_in 'post_summary', with: 'test summary'
      page.execute_script('$(\'#form-post input[name="tags"]\').val(\'owen,dota\')')
    end
    click_button 'Create'
    expect(page).to have_css('.alert-success')

    created_post = CamaleonCms::Post.last.decorate

    # visit page in frontend
    visit created_post.the_url(as_path: true)
    expect(page).to have_text('Pants are pretty sweet.')
  end

  it 'Can edit and update a post' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      fill_in 'post_title', with: 'Test Title changed'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet. chaged")')
      fill_in 'post_summary', with: 'test summary changed'
    end
    click_button 'Update'
    expect(page).to have_css('.alert-success')

    # visit page in frontend
    visit post.the_url(as_path: true)
    expect(page).to have_text('Test Title changed')
  end

  # Regression: on a cold server, opening the edit form in a throttled background tab could bring up
  # TinyMCE empty even though the server rendered the post content -- the field's live value was
  # blanked before TinyMCE read it (surfaced by the PluginRoutes reload changes in #1163). The init
  # guard in cama_get_tinymce_settings restores the server value (textarea.defaultValue) when the
  # editor comes up empty. The throttling race is not reproducible headlessly, so this drives the
  # exact state it produces -- empty live value, server value still in defaultValue -- and asserts
  # the guard refills the editor. Without the guard the editor stays empty and this fails.
  it 'restores the server-rendered content when the editor initializes empty' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    page.execute_script(<<~JS)
      tinymce.get('post_content').remove();
      var ta = document.getElementById('post_content');
      ta.defaultValue = '<p>Cold-boot guard body</p>';
      ta.value = '';
      tinymce.init(cama_get_tinymce_settings({ selector: '#post_content' }));
    JS
    wait(2)

    within_frame('post_content_ifr') do
      expect(page).to have_text('Cold-boot guard body')
    end
  end

  # Regression: space is not a tag delimiter. Multi-word tag names are legal (update_tags
  # documents "Tag1,Tag two,tag new" and the sidebar joins them with ","), but passing
  # `delimiter: ',; '` to tagEditor made the editor split them at form load and rewrite the
  # hidden tags field, so merely opening a post and saving it (or the draft autosave firing)
  # corrupted its stored tags.
  it 'keeps a multi-word tag intact in the tag editor' do
    post.update_tags('new york')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      expect(page).to have_css('.tag-editor .tag-editor-tag', count: 1)
      expect(find('.tag-editor .tag-editor-tag').text).to eq('new york')
      expect(find('input[name="tags"]', visible: :all).value).to eq('new york')
    end
  end

  # Regression: pressing Enter on a typed tag must commit it. The active-input guard added
  # in the jQuery 3 rework swallowed the plugin's own synthetic clicks -- Enter/Tab/arrow
  # keys commit by triggering a click on the editor -- so a typed tag could only be
  # committed with a delimiter character or by clicking outside the field.
  it 'commits a typed tag with Enter' do
    post.update_tags('')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      find('.tag-editor').click
      find('.tag-editor .tag-editor-tag.active input').send_keys('ruby', :enter)

      expect(page).to have_css('.tag-editor .tag-editor-tag', text: 'ruby')
      expect(find('input[name="tags"]', visible: :all).value).to eq('ruby')
    end
  end

  # Regression: a capture-phase input listener ran update_globals() on every keystroke,
  # leaking the uncommitted partial tag into the hidden tags field -- where the 60-second
  # draft autosave persisted it as a permanent PostTag -- and filtering a suggestion out of
  # the dropdown at the exact moment its full name was typed. Suggestions are now filtered
  # through Awesomplete's filter option against committed tags only.
  it 'does not leak uncommitted tag text into the tags field while typing' do
    post.update_tags('ruby,rails')
    post.update_tags('') # keep the PostTag rows as autocomplete suggestions, none assigned
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      find('.tag-editor').click
      find('.tag-editor .tag-editor-tag.active input').send_keys('ruby')

      expect(find('input[name="tags"]', visible: :all).value).to eq('')
      expect(page).to have_css('.awesomplete li', text: 'ruby')
    end
  end

  it 'does not suggest tags already added to the post' do
    post.update_tags('ruby,rails')
    post.update_tags('') # keep the PostTag rows as autocomplete suggestions, none assigned
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      find('.tag-editor').click
      find('.tag-editor .tag-editor-tag.active input').send_keys('ruby', :enter)
      find('.tag-editor .tag-editor-tag.active input').send_keys('r')

      expect(page).to have_css('.awesomplete li', text: 'rails')
      expect(page).to have_no_css('.awesomplete li', text: 'ruby')
    end
  end

  # Regression: SortableJS's filter for the spacer/edit input ran with the default
  # preventOnFilter, preventDefaulting mousedown on the input -- so clicking inside an
  # edited tag could not place the caret or select text.
  it 'places the caret when clicking inside an edited tag input' do
    post.update_tags('alpha,beta')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      find('.tag-editor .tag-editor-tag', text: 'alpha').click
      find('.tag-editor .tag-editor-tag.active input')

      prevented = page.evaluate_script(<<~JS)
        (function() {
          var input = document.querySelector('.tag-editor .tag-editor-tag.active input');
          var ev = new MouseEvent('mousedown', { bubbles: true, cancelable: true });
          input.dispatchEvent(ev);
          return ev.defaultPrevented;
        })()
      JS
      expect(prevented).to be false
    end
  end

  # Regression: the SortableJS init ran unconditionally and threw a ReferenceError when
  # SortableJS was not bundled (custom downstream manifests), aborting the construction
  # of every other tag editor in the same jQuery collection.
  it 'builds the editor even when SortableJS is not loaded' do
    post.update_tags('alpha,beta')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    result = page.evaluate_script(<<~JS)
      (function() {
        var orig = window.Sortable;
        window.Sortable = undefined;
        try {
          var $field = $('<input class="tageditor-guard-probe" value="one,two">').appendTo('body');
          $field.tagEditor({ initialTags: [] });
          var built = $field.next('.tag-editor').find('.tag-editor-tag').length >= 2;
          $field.tagEditor('destroy');
          return { err: null, built: built };
        } catch (e) {
          return { err: e.message, built: false };
        } finally {
          window.Sortable = orig;
        }
      })()
    JS
    expect(result['err']).to be_nil
    expect(result['built']).to be true
  end

  # Regression: after picking an autocomplete suggestion the follow-up input opened at
  # the END of the tag list -- activeTag.next('li') looked for li siblings of a div.
  # Pre-jQuery-3 it resolved via closest('li') and opened right after the edited tag.
  it 'opens the follow-up input right after the edited tag on suggestion select' do
    post.update_tags('alpha,beta,gamma')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      find('.tag-editor .tag-editor-tag', text: 'alpha').click
      find('.tag-editor .tag-editor-tag.active input')

      page.execute_script(<<~JS)
        (function() {
          var input = document.querySelector('.tag-editor .tag-editor-tag.active input');
          input.dispatchEvent(new CustomEvent('awesomplete-selectcomplete', { bubbles: true }));
        })()
      JS
      wait(1) # the follow-up input opens from a 200ms setTimeout

      position = page.evaluate_script(<<~JS)
        (function() {
          var activeLi = jQuery('.tag-editor .tag-editor-tag.active').closest('li')[0];
          return jQuery('.tag-editor li').index(activeLi);
        })()
      JS
      # li layout: [min-height dummy, alpha, beta, gamma] -- the follow-up input must
      # open on beta (right after alpha), not after the last tag (index 4)
      expect(position).to eq(2)
    end
  end

  # Regression (PR #1169 review finding #5, TE-CLICK-PHANTOM): the Awesomplete dropdown lives inside
  # the editor, so a REAL mouse click on a suggestion bubbled to ed's click handler after
  # selectcomplete had already detached the clicked node, defeating the tag guard and appending a
  # phantom input -- which the 200ms follow-up then removed, leaving the editor with no open input.
  # (The synthetic-event spec above cannot see this: no real click bubbles.)
  it 'keeps an input open after picking a suggestion with a real click' do
    post.update_tags('ruby,rails,alpha')
    post.update_tags('alpha') # post keeps 'alpha'; ruby/rails remain as autocomplete suggestions
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      find('.tag-editor').click # open a new-tag input at the end
      find('.tag-editor .tag-editor-tag.active input').send_keys('ru')
      find('.awesomplete li', text: 'ruby').click # REAL click on the suggestion
      wait(1) # the follow-up input opens from a 200ms setTimeout

      expect(page).to have_css('.tag-editor .tag-editor-tag', text: 'ruby')     # suggestion committed
      expect(page).to have_css('.tag-editor .tag-editor-tag', text: 'alpha')    # original kept
      expect(page).to have_css('.tag-editor .tag-editor-tag.active input')      # an input stays open
      # no empty phantom pill left behind: exactly the two real tags
      expect(page).to have_css('.tag-editor .tag-editor-tag:not(.active)', count: 2)
    end
  end

  # Regression: every tag activation created a new Awesomplete instance that was never
  # destroyed, accumulating instances and detached DOM in Awesomplete.all forever.
  # Covers both blur paths: commit (input markup replaced) and empty-tag removal
  # (input li removed -- jQuery's cleanData wipes the element data there, so the
  # instance must be released before the removal).
  it 'releases the autocomplete instance when a tag input closes' do
    post.update_tags('alpha,beta')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      before = page.evaluate_script('window.Awesomplete.all.length')

      # commit cycles: open each tag for editing, close it with Escape
      2.times do
        %w[alpha beta].each do |tag|
          find('.tag-editor .tag-editor-tag', text: tag).click
          find('.tag-editor .tag-editor-tag.active input')
          find('.tag-editor .tag-editor-tag.active input').send_keys(:escape)
          wait(1)
        end
      end

      # empty-tag removal path: clear the input, blur via another form field
      find('.tag-editor .tag-editor-tag', text: 'alpha').click
      find('.tag-editor .tag-editor-tag.active input')
      page.execute_script("document.querySelector('.tag-editor .tag-editor-tag.active input').value = ''")
      fill_in 'post_title', with: 'blur the tag input'
      wait(1)

      after = page.evaluate_script('window.Awesomplete.all.length')
      expect(after).to eq(before)
    end
  end

  # Regression: the dropdown overflow escape hatch used :has(), which browsers without
  # support (Firefox ESR < 121) drop silently -- the Awesomplete dropdown was clipped
  # invisible. Overflow is now unclipped via classes toggled on activation/commit.
  it 'unclips the tag editor for the dropdown via editing classes, not :has()' do
    post.update_tags('alpha,beta')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    within('#form-post') do
      expect(page).to have_no_css('.tag-editor.tag-editor-editing')
      find('.tag-editor .tag-editor-tag', text: 'alpha').click
      find('.tag-editor .tag-editor-tag.active input')
      expect(page).to have_css('.tag-editor.tag-editor-editing')
      expect(page).to have_css('.tag-editor li.tag-editor-editing')

      fill_in 'post_title', with: 'blur the tag input' # moves focus, commits the tag
      expect(page).to have_no_css('.tag-editor.tag-editor-editing')
      expect(page).to have_no_css('.tag-editor li.tag-editor-editing')
    end

    # guard the source against reintroducing :has() (invisible to our Chrome-based specs)
    css = File.read(CamaleonCms::Engine.root.join(
                      'app/assets/stylesheets/camaleon_cms/admin/tageditor/_jquery.tag-editor.css.scss'
                    ))
    expect(css).not_to include(':has(')
  end

  # Regression (PR #1169 review, TE-ACO-CONTRACT): the Awesomplete adapter must keep
  # the jQuery-UI autocomplete option contract for downstream tagEditor callers:
  # function sources are invoked with a {term: ...} request object, string sources
  # are fetched as url?term= (a URL handed to Awesomplete directly throws a
  # DOMException), minLength maps onto minChars, and select receives ui.item with
  # both value and label.
  it 'keeps the jQuery-UI autocomplete option contract' do
    post.update_tags('')
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    result = evaluate_script(<<~JS)
      (function() {
        var out = {sourceTerm: null, minChars: null, selectItem: null, threw: false,
                   getUrl: null, getTerm: null};
        // tagEditor builds its .tag-editor list as a sibling AFTER the field
        function openProbe(id, opts) {
          var $field = $('<input id="' + id + '">').appendTo('body');
          $field.tagEditor($.extend({initialTags: ['seed']}, {autocomplete: opts}));
          var ed = $field.next('.tag-editor');
          window.getSelection().removeAllRanges();
          ed.trigger('click', [ed.find('.tag-editor-tag').first()]);
          return {field: $field, ed: ed};
        }
        try {
          var probe = openProbe('te-contract-fn', {
            minLength: 2,
            source: function(req, cb) {
              out.sourceTerm = (req instanceof Object && typeof req.term === 'string') ? req.term : null;
              cb(['alpha']);
            },
            select: function(e, ui) { out.selectItem = ui.item; }
          });
          var input = probe.ed.find('.tag-editor-tag.active input');
          out.minChars = input.data('awesomplete').minChars;
          input.val('al').trigger('input');
          var ev = new CustomEvent('awesomplete-selectcomplete');
          ev.text = {value: 'alpha', label: 'Alpha'};
          input[0].dispatchEvent(ev);
          probe.field.tagEditor('destroy');
        } catch (err) { out.threw = err.name + ': ' + err.message; }

        try {
          var origGet = $.get;
          $.get = function(url, params) {
            out.getUrl = url; out.getTerm = params && params.term;
            return {done: function(cb) { cb(['x']); return this; }};
          };
          var probe2 = openProbe('te-contract-url', {source: '/suggestions'});
          probe2.ed.find('.tag-editor-tag.active input').val('al').trigger('input');
          $.get = origGet;
          probe2.field.tagEditor('destroy');
        } catch (err) { out.threw = out.threw || (err.name + ': ' + err.message); }
        return out;
      })()
    JS

    expect(result['threw']).to be_falsey
    expect(result['sourceTerm']).to eq('al')
    expect(result['minChars']).to eq(2)
    expect(result['selectItem']).to include('value' => 'alpha', 'label' => 'Alpha')
    expect(result['getUrl']).to eq('/suggestions')
    expect(result['getTerm']).to eq('al')
  end

  # Covers the shared TinyMCE drag helpers in _custom_fields.js (deduped from the two
  # Sortable inits): dragging a row must detach the editors inside it (SortableJS moves
  # the DOM, which breaks a live editor) and re-attach them on drop. The handlers are
  # driven directly with the {item: <dragged element>} shape SortableJS passes, because
  # emulating a real HTML5 drag headlessly is unreliable.
  it 'detaches and restores TinyMCE editors around a drag' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/#{post.id}/edit"
    wait(2)

    result = page.evaluate_script(<<~JS)
      (function() {
        var evt = { item: document.querySelector('#form-post') };
        var before = !!tinymce.get('post_content');
        cama_detach_editors_for_drag(evt);
        var detached = tinymce.get('post_content') == null;
        var marked = document.querySelector('#post_content').classList.contains('cama_restore_editor');
        cama_restore_editors_after_drag(evt);
        var restored = !!tinymce.get('post_content');
        return { before: before, detached: detached, marked: marked, restored: restored };
      })()
    JS
    expect(result).to eq('before' => true, 'detached' => true, 'marked' => true, 'restored' => true)
  end

  describe 'when visibility post plugin is enabled' do
    it 'correctly fetches the assets' do
      plugin_install('visibility_post')
      admin_sign_in
      visit "#{cama_root_relative_path}/admin/post_type/#{post_type_id}/posts/new"
      wait(2)

      within('#form-post') do
        within('#published_from') do
          find('span.glyphicon.glyphicon-calendar')
        end

        expect(webfont_icon_fetch_status('glyphicon glyphicon-calendar', 'glyphicons-halflings', 'woff2')).to be(200)
      end
    end
  end
end
