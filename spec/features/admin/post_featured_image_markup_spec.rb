# frozen_string_literal: true

# The Featured Image panel of the post form put the name of the picked file into HTML. An upload
# cleans the name of a file, but a file that reaches the storage another way keeps its name. A name
# with markup then ran its event handler in the session of the admin who picked the file. The panel
# must show the name as text.
#
# The Upload Image link of the panel also put three options of the post type into the JavaScript of
# its click handler. A role with the settings permission can store such an option. A quote in the
# option ended the String there, and the rest of the option ran as script. The handler must get each
# option as text.
RSpec.describe 'the Featured Image panel of the post form', :js do
  init_site

  let(:name) { '<img src=q onerror="return">.png' }
  let(:uploader) { CamaleonCmsLocalUploader.new(current_site: @site) }
  # The uploader stores a key as it is. An upload through the media manager cleans the file name.
  let(:image) do
    uploader.add_file("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", "/#{name}", same_name: true)
  end

  let(:edit_path) { "#{cama_root_relative_path}/admin/post_type/#{@post.post_type.id}/posts/#{@post.id}/edit" }
  let(:picker) { "$('#cama_modal_file_uploader #cama_media_gallery')" }

  before { admin_sign_in }

  after { FileUtils.rm_f(@site.upload_directory(name)) }

  it 'shows the name of the picked file as text' do
    image
    visit edit_path

    # A mouse click can miss while the text editor loads and while the modal moves into its place,
    # so the example clicks with jQuery.
    page.execute_script("$('#feature-image ~ a').trigger('click')")
    expect(page).to have_css('#cama_modal_file_uploader .file_item', wait: 10)
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

  it 'gives an option of the post type with a quote to the file picker as text' do
    option = "x'});window.optionRan=1;({a:'"
    @post.post_type.set_option('posts_thumb_versions', option)
    visit edit_path

    page.execute_script("$('#feature-image ~ a').trigger('click')")
    expect(page).to have_css('#cama_modal_file_uploader #cama_media_gallery', wait: 10)
    expect(page.evaluate_script("#{picker}.attr('data-versions')")).to eq(option)
    expect(page.evaluate_script('window.optionRan')).to be_nil
  end
end
