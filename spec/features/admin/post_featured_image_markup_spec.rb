# frozen_string_literal: true

# The Featured Image panel of the post form put the name of the picked file into HTML. An upload
# cleans the name of a file, but a file that reaches the storage another way keeps its name. A name
# with markup then ran its event handler in the session of the admin who picked the file. The panel
# must show the name as text.
RSpec.describe 'the Featured Image panel of the post form', :js do
  init_site

  let(:name) { '<img src=q onerror="return">.png' }
  let(:uploader) { CamaleonCmsLocalUploader.new(current_site: @site) }
  # The uploader stores a key as it is. An upload through the media manager cleans the file name.
  let(:image) do
    uploader.add_file("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", "/#{name}", same_name: true)
  end

  before do
    admin_sign_in
    image
    visit "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit"
  end

  after { FileUtils.rm_f(@site.upload_directory(name)) }

  it 'shows the name of the picked file as text' do
    expect(page).to have_css('.sl-slug-edit .sl-url', wait: 10)
    find('#feature-image ~ a', text: 'Upload Image').click
    expect(page).to have_css('#cama_modal_file_uploader .file_item', wait: 10)
    # The modal still moves into its place now, so the example clicks with jQuery, not at a position.
    page.execute_script(<<~JS)
      var modal = $('#cama_modal_file_uploader');
      modal.find('.file_item').filter(function () {
        return $(this).attr('data-key') === #{name.to_json};
      }).trigger('click');
      modal.find('.insert_btn').trigger('click');
    JS

    expect(page).to have_css('#feature-image .meta strong', exact_text: image['name'])
    expect(page).to have_no_css('#feature-image .meta img', visible: :all)
  end
end
