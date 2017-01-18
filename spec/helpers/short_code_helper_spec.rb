require 'rails_helper'

def shortcode_tests
  before(:each) do
    helper.shortcodes_init
    helper.shortcode_add("hello_world", lambda{|attrs, args|
      "Hello World"
    })
    helper.shortcode_add("hello", lambda{|attrs, args|
      "Hello #{attrs['name']}"
    })
    helper.shortcode_add("user_info", lambda{|attrs, args|
      "#{attrs['name']} #{attrs['lastname']}"
    })
    helper.shortcode_add("modal", lambda{|attrs, args|
      "modal body = #{args[:shortcode_content]}"
    })
    helper.shortcode_add("title", lambda{|attrs, args|
      "<h1>#{args[:shortcode_content]}</h1>"
    })
    helper.shortcode_add("sub_title", lambda{|attrs, args|
      "<h2 style='#{attrs['style']}'>#{args[:shortcode_content]}</h2>"
    })
    helper.shortcode_add("sub_title2", lambda{|attrs, args|
      "<h2 style='#{attrs['style']}' class='#{attrs['class']}'>#{args[:shortcode_content]}</h2>"
    })
  end
end

describe "CamaleonCms::ShortCodeHelper" do
  # get_current_test_site()
  describe "Shortcode Simple" do
    shortcode_tests
    it "No attributes" do
      expect(helper.do_shortcode('This is my first [hello_world]')).to include('Hello World')
    end
    it "With attribute" do
      expect(helper.do_shortcode('Say [hello name="Owen"]')).to be == 'Say Hello Owen'
    end
    it "With attributes" do
      expect(helper.do_shortcode('Hi [user_info name="Owen" lastname="Peredo"], Good morning')).to be == 'Hi Owen Peredo, Good morning'
    end
  end

  describe "Shortcode with Block" do
    shortcode_tests
    it "No attributes" do
      expect(helper.do_shortcode('Sample [title]This is title[/title].')).to include('Sample <h1>This is title</h1>.')
    end
    it "With attribute" do
      expect(helper.do_shortcode('Sample [sub_title style="color: red;"]This is sub title[/sub_title].')).to include('Sample <h2 style=\'color: red;\'>This is sub title</h2>.')
    end
    it "With attributes" do
      expect(helper.do_shortcode('Sample [sub_title2 style="color: red;" class="center"]This is sub title[/sub_title2].')).to include('Sample <h2 style=\'color: red;\' class=\'center\'>This is sub title</h2>.')
    end
  end

  describe "Shortcode Multiple" do
    shortcode_tests
    it "Many Shortcodes" do
      expect(helper.do_shortcode('[title][hello name="Owen"][/title] and [hello_world].')).to include('<h1>Hello Owen</h1> and Hello World.')
    end
  end
end