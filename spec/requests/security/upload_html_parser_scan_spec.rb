# frozen_string_literal: true

# The upload scan parsed an HTML file only with the HTML parser of libxml2. That parser reads
# `<!--` as the start of a comment inside an `xmp`, `title`, `textarea` or `noscript` element. A
# browser reads it as text there. So the element after the end tag was in a comment for the scan,
# and in the page for the browser. The byte patterns of the scan do not list each handler name,
# such as `onpointerdown`, so the file passed.
#
# The examples send the file to the media endpoint as a user who has the `media` permission and
# does not have `media_unfiltered_upload`.
RSpec.describe 'Upload scan of an HTML file as a browser parses it', type: :request do
  init_site

  include_context 'with a media-only uploader'

  def html(body)
    %(<html><body>#{body}</body></html>)
  end

  %w[xmp title textarea noscript].each do |tag|
    it "refuses a handler after a comment start in a #{tag} element" do
      upload(html("<#{tag}><!--</#{tag}><img src=x onpointerdown=alert(1)>--></#{tag}>"), extension: '.html')

      expect(response.body).to include(refusal)
    end
  end

  # Nokogiri reads a charset from each tag whose name starts with `meta`. A browser reads it only
  # from a `meta` element.
  it 'refuses a handler after a comment start when a metadata element names a charset' do
    upload(html('<metadata charset=IBM037></metadata><xmp><!--</xmp><img src=x onpointerdown=alert(1)>--></xmp>'),
           extension: '.html')

    expect(response.body).to include(refusal)
  end

  # Chrome 158 keeps an `xmp` element in a `select` element. The HTML5 parser of Nokogiri drops it,
  # and it does not read the content of that element as text.
  {
    'a comment start in an xmp element' =>
      '<select><xmp><!--</xmp><img src=x onpointerdown=alert(1)>--></xmp></select>',
    'an xmp end tag in an option attribute' =>
      '<select><xmp><option title="</xmp><img src=x onpointerdown=alert(1)>"></option></xmp></select>'
  }.each do |content, markup|
    it "refuses a handler after #{content} in a select element" do
      upload(html(markup), extension: '.html')

      expect(response.body).to include(refusal)
    end
  end

  it 'accepts a handler name in a comment' do
    upload(html('<p>text</p><!-- <img src=x onpointerdown=alert(1)> -->'), extension: '.html')

    expect(response.body).not_to include(refusal)
  end
end
