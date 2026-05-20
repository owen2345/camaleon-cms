# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::RuntimeStateConcern do
  let(:runtime_class) do
    Class.new do
      include CamaleonCms::RuntimeStateConcern
    end
  end

  let(:runtime) { runtime_class.new }

  it 'keeps shortcode and theme runtime methods available through the aggregate concern' do
    expect(runtime).to respond_to(
      :shortcodes_init,
      :shortcode_add,
      :shortcode_asset_reference,
      :theme_asset_path,
      :theme_asset_url,
      :theme_asset_file_path,
      :cama_shortcode_data,
      :cama_shortcode_model_parser
    )
  end

  it 'keeps html/content runtime methods available through the aggregate concern' do
    expect(runtime).to respond_to(
      :cama_html_helpers_init,
      :cama_load_libraries,
      :append_asset_libraries,
      :append_asset_content,
      :append_pre_asset_content,
      :cama_draw_pre_asset_contents,
      :cama_draw_custom_assets,
      :cama_content_init,
      :theme_init,
      :breadcrumb_add
    )
  end

  it 'keeps admin menu runtime methods available through the aggregate concern' do
    expect(runtime).to respond_to(
      :admin_menus_add_commons,
      :admin_menu_add_menu,
      :admin_menu_append_menu_item,
      :admin_menu_prepend_menu_item,
      :admin_menu_insert_menu_before,
      :admin_menu_insert_menu_after,
      :cama_comments_get_common_data
    )
  end

  it 'keeps captcha and uploader runtime methods available through the aggregate concern' do
    expect(runtime).to respond_to(
      :cama_captcha_build,
      :upload_file,
      :cama_uploader_generate_thumbnail,
      :uploader_verify_name,
      :cama_file_path_to_url,
      :cama_url_to_file_path,
      :cama_crop_image,
      :cama_resize_and_crop,
      :cama_tmp_upload,
      :cama_resize_upload,
      :cama_uploader,
      :slugify,
      :slugify_folder
    )
  end
end
