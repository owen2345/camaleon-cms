# frozen_string_literal: true

# The upload scan refuses a blocked URI scheme, such as `javascript:`. It decoded a numeric
# character reference before the match, and it did not decode a named one. A browser reads
# `&colon;` as a colon in an HTML file, and in an XML file with a public XHTML DOCTYPE. So a file
# with `href="javascript&colon;alert(1)"` passed the scan, and a click on the link ran the script.
#
# The examples send the file to the media endpoint as a user who has the `media` permission and
# does not have `media_unfiltered_upload`.
RSpec.describe 'Upload scan of a scheme with a named character reference', type: :request do
  init_site

  include_context 'with a media-only uploader'

  let(:xhtml_doctype) do
    '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'
  end

  def html(body)
    %(<html><body>#{body}</body></html>)
  end

  def xhtml(body)
    %(#{xhtml_doctype}<html xmlns="http://www.w3.org/1999/xhtml"><body>#{body}</body></html>)
  end

  describe 'an HTML file' do
    {
      'a colon' => 'javascript&colon;alert(1)',
      'a tab in the scheme' => 'java&Tab;script:alert(1)',
      'a line feed in the scheme' => 'java&NewLine;script:alert(1)'
    }.each do |character, href|
      it "refuses a script link whose reference gives #{character}" do
        upload(html(%(<a href="#{href}">link</a>)), extension: '.html')

        expect(response.body).to include(refusal)
      end
    end

    it 'refuses a data URI whose reference gives the slash of the media type' do
      upload(html('<a href="data:text&sol;html,text">link</a>'), extension: '.html')

      expect(response.body).to include(refusal)
    end

    it 'accepts a text with a reference to a colon and no scheme' do
      upload(html('<p>Open&colon; 10&colon;30</p>'), extension: '.html')

      expect(response.body).not_to include(refusal)
    end
  end

  describe 'an XML file with a public XHTML DOCTYPE' do
    let(:script_link) { xhtml('<a href="javascript&colon;alert(1)">link</a>') }

    it 'refuses a script link whose reference gives the colon' do
      upload(script_link, extension: '.xhtml')

      expect(response.body).to include(refusal)
    end

    it 'refuses the same file in UTF-16' do
      xml = %(<?xml version="1.0" encoding="UTF-16"?>#{script_link})
      upload("\xFF\xFE".b + xml.encode(Encoding::UTF_16LE).b, extension: '.xhtml')

      expect(response.body).to include(refusal)
    end

    # A browser removes the escape sequence `ESC ( B` from a file in ISO-2022-JP. So it reads the
    # bytes `&col`, `ESC ( B` and `on;` as `&colon;`.
    it 'refuses the same file in ISO-2022-JP, with an escape sequence in the reference' do
      link = script_link.sub('&colon;', "&col\e(Bon;")
      upload(%(<?xml version="1.0" encoding="ISO-2022-JP"?>#{link}), extension: '.xhtml')

      expect(response.body).to include(refusal)
    end

    it 'refuses the script link in an SVG file with that DOCTYPE' do
      link = '<a href="javascript&colon;alert(1)"><rect width="10" height="10"/></a>'
      upload(%(#{xhtml_doctype}<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{link}</svg>))

      expect(response.body).to include(refusal)
    end

    it 'accepts a text with a reference to a colon and no scheme' do
      upload(xhtml('<p>Open&colon; 10&colon;30</p>'), extension: '.xhtml')

      expect(response.body).not_to include(refusal)
    end
  end

  # An entity of the file holds a part of the scheme, so the bytes of the file hold no whole
  # scheme. The XML parser drops `&colon;`, which the file does not declare. A browser reads both.
  describe 'an XML file with a public XHTML DOCTYPE that declares an entity' do
    let(:split_link) { '<a href="&a;script&colon;alert(1)">link</a>' }

    def doctype_with(dtd)
      xhtml_doctype.sub(/>\z/, " [#{dtd}]>")
    end

    def xhtml_with_dtd(dtd, body)
      %(#{doctype_with(dtd)}<html xmlns="http://www.w3.org/1999/xhtml"><body>#{body}</body></html>)
    end

    it 'refuses a script link whose scheme an entity and a named reference give' do
      upload(xhtml_with_dtd('<!ENTITY a "java">', split_link), extension: '.xhtml')

      expect(response.body).to include(refusal)
    end

    it 'refuses a script link whose colon is the named reference in an entity value' do
      upload(xhtml_with_dtd('<!ENTITY c "&#38;colon;">', '<a href="javascript&c;alert(1)">link</a>'),
             extension: '.xhtml')

      expect(response.body).to include(refusal)
    end

    it 'refuses the script link in an SVG file' do
      link = '<a href="&a;script&colon;alert(1)"><rect width="10" height="10"/></a>'
      upload(doctype_with('<!ENTITY a "java">') +
             %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{link}</svg>))

      expect(response.body).to include(refusal)
    end

    # The parser stops its reports after 100, so it does not report the `&colon;` of this file.
    it 'refuses the script link after 100 other references that the file does not declare' do
      upload(xhtml_with_dtd('<!ENTITY a "java">', "<p>#{'&nbsp;' * 100}</p>#{split_link}"), extension: '.xhtml')

      expect(response.body).to include(refusal)
    end

    it 'accepts a file that refers to another name that it does not declare' do
      upload(xhtml_with_dtd('<!ENTITY a "text">', '<p>&a; a&nbsp;b</p>'), extension: '.xhtml')

      expect(response.body).not_to include(refusal)
    end

    it 'accepts a file that declares the name' do
      upload(xhtml_with_dtd('<!ENTITY colon ":">', '<p>10&colon;30</p>'), extension: '.xhtml')

      expect(response.body).not_to include(refusal)
    end
  end
end
