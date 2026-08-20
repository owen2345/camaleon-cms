# frozen_string_literal: true

require 'rails_helper'

def shortcode_tests
  before do
    helper.shortcodes_init
    helper.shortcode_add('hello_world', lambda { |_attrs, _args|
      'Hello World'
    })
    helper.shortcode_add('hello', lambda { |attrs, _args|
      "Hello #{attrs['name']}"
    })
    helper.shortcode_add('user_info', lambda { |attrs, _args|
      "#{attrs['name']} #{attrs['lastname']}"
    })
    helper.shortcode_add('modal', lambda { |_attrs, args|
      "modal body = #{args[:shortcode_content]}"
    })
    helper.shortcode_add('title', lambda { |_attrs, args|
      "<h1>#{args[:shortcode_content]}</h1>"
    })
    helper.shortcode_add('sub_title', lambda { |attrs, args|
      "<h2 style='#{attrs['style']}'>#{args[:shortcode_content]}</h2>"
    })
    helper.shortcode_add('sub_title2', lambda { |attrs, args|
      "<h2 style='#{attrs['style']}' class='#{attrs['class']}'>#{args[:shortcode_content]}</h2>"
    })
  end
end

describe 'CamaleonCms::ShortCodeHelper' do
  describe 'Shortcode Simple' do
    shortcode_tests
    it 'No attributes' do
      expect(helper.do_shortcode('This is my first [hello_world]')).to include('Hello World')
    end

    it 'With attribute' do
      expect(helper.do_shortcode('Say [hello name="Owen"]')).to eq('Say Hello Owen')
    end

    it 'With attributes' do
      expect(helper.do_shortcode('Hi [user_info name="Owen" lastname="Peredo"], Good morning'))
        .to eq('Hi Owen Peredo, Good morning')
    end
  end

  describe 'Shortcode with Block' do
    shortcode_tests
    it 'No attributes' do
      expect(helper.do_shortcode('Sample [title]This is title[/title].'))
        .to include('Sample <h1>This is title</h1>.')
    end

    it 'With attribute' do
      expect(helper.do_shortcode('Sample [sub_title style="color: red;"]This is sub title[/sub_title].'))
        .to include('Sample <h2 style=\'color: red;\'>This is sub title</h2>.')
    end

    it 'With attributes' do
      expect(
        helper.do_shortcode('Sample [sub_title2 style="color: red;" class="center"]This is sub title[/sub_title2].')
      ).to include('Sample <h2 style=\'color: red;\' class=\'center\'>This is sub title</h2>.')
    end
  end

  describe 'Shortcode Multiple' do
    shortcode_tests
    it 'Many Shortcodes' do
      expect(helper.do_shortcode('[title][hello name="Owen"][/title] and [hello_world].'))
        .to include('<h1>Hello Owen</h1> and Hello World.')
    end
  end

  describe 'CurrentRequest-backed shortcode state' do
    it 'stores shortcode registrations in CurrentRequest' do
      helper.shortcodes_init
      callback = ->(_attrs, _args) { 'Links' }

      helper.shortcode_add('profile_social', callback, 'social links')

      expect(CurrentRequest.shortcodes).to include('profile_social')
      expect(CurrentRequest.shortcodes_template['profile_social']).to eq(callback)
      expect(CurrentRequest.shortcodes_descr['profile_social']).to eq('social links')
    end
  end

  describe 'Asset shortcode' do
    let(:current_theme) { instance_double(CamaleonCms::Theme) }
    let(:current_theme_asset_path) { '/tmp/cv/assets/img/signature.png' }
    let(:remapped_asset) { 'themes/cv/assets/img/signature.png' }

    before do
      helper.shortcodes_init
      allow(helper).to receive(:current_theme).and_return(current_theme)
      allow(helper).to receive(:theme_asset_path).with('img/signature.png').and_return(remapped_asset)
      allow(helper).to receive(:theme_asset_file_path).with('img/signature.png').and_return(current_theme_asset_path)
      allow(File).to receive(:exist?).and_call_original
    end

    it 'remaps theme asset shortcodes to the active theme when the asset exists there' do
      allow(File).to receive(:exist?).with(current_theme_asset_path).and_return(true)

      output = helper.do_shortcode("[asset as_path='true' file='themes/camaleon_cms/assets/img/signature.png']")

      expect(output).to eq('/themes/cv/assets/img/signature.png')
    end

    it 'uses the active theme asset path for image tags too' do
      allow(File).to receive(:exist?).with(current_theme_asset_path).and_return(true)

      output = helper.do_shortcode("[asset image='true' file='themes/camaleon_cms/assets/img/signature.png']")

      expect(output).to include('src="/themes/cv/assets/img/signature.png"')
    end

    it 'keeps the original theme asset path when the active theme does not have the asset' do
      allow(File).to receive(:exist?).with(current_theme_asset_path).and_return(false)

      output = helper.do_shortcode("[asset as_path='true' file='themes/camaleon_cms/assets/img/signature.png']")

      expect(output).to eq('/themes/camaleon_cms/assets/img/signature.png')
    end
  end
end
