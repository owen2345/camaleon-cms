# frozen_string_literal: true

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

RSpec.describe 'CamaleonCms::ShortCodeHelper' do
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

  describe 'Shortcode output' do
    shortcode_tests
    let(:backslashes) { %q(\0 \& \' \` \\\\ \1 \k<x>) }

    before do
      text = backslashes
      helper.shortcode_add('backslashes', ->(_attrs, _args) { text })
      helper.shortcode_add('mirror', ->(_attrs, _args) { "<i title='[hello_world]'></i>" })
      helper.shortcode_add('closer', ->(_attrs, _args) { '[/title]' })
    end

    it 'shows a backslash sequence of an output as written' do
      expect(helper.do_shortcode('a [backslashes] b')).to eq("a #{backslashes} b")
    end

    it 'shows a backslash sequence as written when render_shortcode replaces the shortcode' do
      expect(helper.render_shortcode('a [backslashes] b', 'backslashes')).to eq("a #{backslashes} b")
    end

    it 'does not replace the text of a later shortcode inside the output of an earlier one' do
      expect(helper.do_shortcode('[mirror] and [hello_world]'))
        .to eq("<i title='[hello_world]'></i> and Hello World")
    end

    it 'does not replace the text of a later shortcode inside an earlier output in an enclosing shortcode' do
      expect(helper.do_shortcode('[title][mirror][hello_world][/title]'))
        .to eq("<h1><i title='[hello_world]'></i>Hello World</h1>")
    end

    it 'reads a closing tag in an earlier output as text' do
      expect(helper.do_shortcode('[closer] [title]Name')).to eq('[/title] <h1></h1>Name')
    end

    it 'reads a closing tag before the shortcode as text' do
      expect(helper.do_shortcode('[/title] [title]Name')).to eq('[/title] <h1></h1>Name')
    end

    # The inner text of an enclosing shortcode ends at its closing tag. A closing tag after it belongs
    # to no child of that shortcode, so a later shortcode is no child of such a child.
    it 'replaces a shortcode after an enclosing shortcode whose child has a later closing tag' do
      expect(helper.do_shortcode('[title][hello_world][/title] [hello name="Owen"] [/hello_world]'))
        .to eq('<h1>Hello World</h1> Hello Owen [/hello_world]')
    end

    it 'does not replace the text of a later shortcode in the output of such a child' do
      expect(helper.do_shortcode('[title][mirror][/title] [hello_world] [/mirror]'))
        .to eq("<h1><i title='[hello_world]'></i></h1> Hello World [/mirror]")
    end

    it 'reads a Hash output by the shortcode text, as String#sub did' do
      helper.shortcode_add('assets', ->(_attrs, _args) { { front_grid_editor: { css: ['basic.css'] } } })
      helper.shortcode_add('keyed', ->(_attrs, _args) { { '[keyed]' => 'Value' } })

      expect(helper.do_shortcode('a [assets] b [keyed] c')).to eq('a  b Value c')
    end

    it 'raises a TypeError for an output that is no String, as String#sub did' do
      helper.shortcode_add('nothing', ->(_attrs, _args) {})

      expect { helper.do_shortcode('a [nothing] b') }.to raise_error(TypeError)
    end

    # One Hash holds the arguments of all shortcodes of a text. Before, a shortcode with no closing tag
    # read the inner text of an earlier enclosing shortcode there.
    it 'gives no inner text to a shortcode with no closing tag after an enclosing shortcode' do
      expect(helper.do_shortcode('[title]First[/title] [title] [modal]'))
        .to eq('<h1>First</h1> <h1></h1> modal body = ')
    end

    it 'gives a child with no closing tag no inner text of its parent' do
      expect(helper.do_shortcode('[title]Name [modal][/title]')).to eq('<h1>Name modal body = </h1>')
    end

    it 'gives an enclosing shortcode its inner text as written' do
      contents = []
      helper.shortcode_add('collect', lambda { |_attrs, args|
        contents << args[:shortcode_content]
        args[:shortcode_content]
      })

      expect(helper.do_shortcode('[collect][hello name="Owen"][/collect]')).to eq('Hello Owen')
      expect(contents).to eq(['[hello name="Owen"]'])
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
