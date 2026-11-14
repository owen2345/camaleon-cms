# frozen_string_literal: true

# The upload plugin of the media manager put the name of each selected file into HTML. It did so in
# its status bar, and in each message that refuses a file. A file on the computer of a user can have
# markup in its name. That markup then ran its event handler in the session of the user who selected
# the file. The plugin must show the name as text.
RSpec.describe 'the name of a selected file in the upload plugin of the media manager', :js do
  init_site

  let(:name) { '<img src=q onerror="return">.png' }
  let(:folder) { Dir.mktmpdir }
  let(:file) do
    File.join(folder, name).tap { |path| FileUtils.cp("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", path) }
  end

  before do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/media"
  end

  after { FileUtils.rm_rf(folder) }

  # The helper starts an upload plugin of its own with the given options. It sends no file.
  def start_uploader(options)
    page.execute_script(<<~JS)
      var target = $('<div id="own"><div class="target"></div></div>').appendTo('body');
      window.own = target.find('.target').uploadFile(
        $.extend({ url: '/', fileName: 'own', autoSubmit: false }, #{options.to_json})
      );
    JS
  end

  it 'shows the name as text in the status bar' do
    # The status bar of a file goes away when its upload ends. The example stops the request, so
    # that the status bar stays.
    page.execute_script('XMLHttpRequest.prototype.send = function () {};')
    attach_file('file_upload[]', file, make_visible: true)

    expect(page).to have_css('.ajax-file-upload-filename', text: name)
    expect(page).to have_no_css('.ajax-file-upload-filename img', visible: :all)
  end

  {
    'a file type that the options do not allow' => { allowedTypes: 'jpg' },
    'a file above the size limit' => { maxFileSize: 1 },
    'a file above the count limit' => { maxFileCount: 0 },
    'a file above the count limit of a plugin that sends a form' => { maxFileCount: 0, serialize: false }
  }.each do |flow, options|
    it "shows the name as text in the message for #{flow}" do
      start_uploader(options)
      attach_file('own[]', file, make_visible: true)

      expect(page).to have_css('#own .ajax-file-upload-error b', text: name)
      expect(page).to have_no_css('#own img[onerror]', visible: :all)
    end
  end

  it 'shows the name as text in the message for a file that the plugin holds already' do
    start_uploader(allowDuplicates: false)
    attach_file('own[]', file, make_visible: true)
    expect(page).to have_css('#own .ajax-file-upload-filename', text: name)
    attach_file('own[]', file, make_visible: true)

    expect(page).to have_css('#own .ajax-file-upload-error b', exact_text: name)
    expect(page).to have_no_css('#own img[onerror]', visible: :all)
  end

  it 'shows the name as text in the status bar of a plugin that sends a form' do
    start_uploader(serialize: false)
    attach_file('own[]', file, make_visible: true)

    expect(page).to have_css('#own .ajax-file-upload-filename', text: name)
    expect(page).to have_no_css('#own img[onerror]', visible: :all)
  end

  it 'shows the name as text in the status bar that createProgress adds' do
    start_uploader({})
    page.execute_script("window.own.createProgress(#{name.to_json}, '', 1)")

    expect(page).to have_css('#own .ajax-file-upload-filename', text: name)
    expect(page).to have_no_css('#own img[onerror]', visible: :all)
  end
end
