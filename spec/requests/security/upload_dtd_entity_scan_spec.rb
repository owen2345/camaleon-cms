# frozen_string_literal: true

# The upload scan read a DTD entity as a reference, and did not read the markup that the entity
# expands to. A browser expands the entity when it shows the file. The parser decodes a character
# reference in the entity value before it reads the value as markup. So `&#111;nerror` in an entity
# value is an `onerror` attribute in the browser, and the byte patterns of the scan do not see it.
#
# The scan also did not read an attribute default of the DTD, which a browser adds to the element.
#
# The examples send the file to the media endpoint as a user who has the `media` permission and
# does not have `media_unfiltered_upload`.
RSpec.describe 'Upload scan of the content of a DTD', type: :request do
  init_site

  include_context 'with a media-only uploader'

  def svg(dtd, body, doctype_id: '')
    %(<?xml version="1.0"?><!DOCTYPE svg #{doctype_id}[#{dtd}]>) +
      %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{body}</svg>)
  end

  describe 'an entity that expands to markup' do
    let(:hidden_handler) { svg(%q(<!ENTITY x "<image href='x' &#111;nerror='alert(1)'/>">), '&x;') }

    %w[.svg .xml .xhtml .xsl].each do |extension|
      it "refuses a handler name with a character reference in a #{extension} file" do
        upload(hidden_handler, extension: extension)

        expect(response.body).to include(refusal)
      end
    end

    it 'refuses a handler name with a character reference when a character reference gives the tag start' do
      upload(svg(%q(<!ENTITY x "&#60;image href='x' &#111;nerror='alert(1)'/>">), '&x;'))

      expect(response.body).to include(refusal)
    end

    it 'refuses a foreignObject element' do
      upload(svg(%q(<!ENTITY x "<foreignObject><p xmlns='http://www.w3.org/1999/xhtml'>text</p></foreignObject>">),
                 '&x;'))

      expect(response.body).to include(refusal)
    end

    it 'refuses a script element whose name has a character reference' do
      upload(svg('<!ENTITY x "<&#115;cript>alert(1)</&#115;cript>">', '&x;'))

      expect(response.body).to include(refusal)
    end

    it 'refuses the markup of an entity that another entity refers to' do
      upload(svg(%q(<!ENTITY a "&b;"><!ENTITY b "<image href='x' &#111;nerror='alert(1)'/>">), '&a;'))

      expect(response.body).to include(refusal)
    end

    it 'refuses the markup of an entity that a parameter entity declares' do
      declaration = "<!ENTITY x '&#60;image href=&#34;x&#34; &#111;nerror=&#34;alert(1)&#34;/>'>"
      upload(svg(%(<!ENTITY % p "#{declaration}"> %p;), '&x;'))

      expect(response.body).to include(refusal)
    end
  end

  describe 'an entity that expands to a part of an attribute value' do
    it 'refuses a script scheme outside of an href attribute' do
      upload(svg('<!ENTITY a "java">', '<a><set attributeName="href" to="&a;script:alert(1)"/><text>t</text></a>'))

      expect(response.body).to include(refusal)
    end
  end

  describe 'an entity that the scan cannot read' do
    it 'refuses a general entity that points to another resource' do
      upload(svg('<!ENTITY x SYSTEM "other.txt">', '<text>&x;</text>'))

      expect(response.body).to include(refusal)
    end

    it 'refuses a parameter entity that points to another resource' do
      upload(svg('<!ENTITY % p SYSTEM "other.dtd"> %p;', '<text>t</text>'))

      expect(response.body).to include(refusal)
    end
  end

  describe 'an entity bomb' do
    it 'refuses entities that expand to a billion characters' do
      levels = (1..8).map { |n| %(<!ENTITY l#{n} "#{"&l#{n - 1};" * 10}">) }.join
      upload(svg(%(<!ENTITY l0 "aaaaaaaaaa">#{levels}), '<text>&l8;</text>'))

      expect(response.body).to include(refusal)
    end

    it 'refuses one large entity with many references' do
      upload(svg(%(<!ENTITY a "#{'a' * 100_000}">), "<text>#{'&a;' * 20_000}</text>"))

      expect(response.body).to include(refusal)
    end

    it 'refuses an entity that refers to itself' do
      upload(svg('<!ENTITY a "&b;"><!ENTITY b "&a;">', '<text>&a;</text>'))

      expect(response.body).to include(refusal)
    end

    it 'refuses an entity whose value refers to the entity itself' do
      upload(svg('<!ENTITY a "&a;">', '<text>&a;</text>'))

      expect(response.body).to include(refusal)
    end
  end

  # A browser gives an element each attribute default that the DTD declares for it. So the `svg`
  # element of the first file has an `onload` handler, and no tag of the file holds that attribute.
  describe 'an attribute default of the DTD' do
    let(:shape) { '<rect width="10" height="10"/>' }

    %w[.svg .xml .xhtml .xsl].each do |extension|
      it "refuses a default for a handler attribute in a #{extension} file" do
        upload(svg('<!ATTLIST svg onload CDATA "alert(1)">', shape), extension: extension)

        expect(response.body).to include(refusal)
      end
    end

    it 'refuses a fixed default for a handler attribute' do
      upload(svg('<!ATTLIST rect onclick CDATA #FIXED "alert(1)">', shape))

      expect(response.body).to include(refusal)
    end

    it 'refuses a default with a script scheme that an entity completes' do
      upload(svg('<!ENTITY j "java"><!ATTLIST a href CDATA "&j;script:alert(1)">', "<a>#{shape}</a>"))

      expect(response.body).to include(refusal)
    end

    # The parser keeps this declaration with no default, because `alert(1)` is no name token. It
    # still gives the element that default.
    it 'refuses a handler default that does not fit the type of the attribute' do
      upload(svg('<!ATTLIST svg onload NMTOKEN "alert(1)">', shape))

      expect(response.body).to include(refusal)
    end

    # The parser keeps only the first declaration of an attribute. A browser uses the first
    # declaration that has a default.
    it 'refuses a handler default in a second declaration of the attribute' do
      upload(svg('<!ATTLIST svg onload CDATA #IMPLIED><!ATTLIST svg onload CDATA "alert(1)">', shape))

      expect(response.body).to include(refusal)
    end

    it 'accepts a default for an attribute that is no handler' do
      upload(svg('<!ATTLIST svg xmlns:xlink CDATA #FIXED "http://www.w3.org/1999/xlink">', shape))

      expect(response.body).not_to include(refusal)
    end

    it 'accepts a handler attribute that the DTD declares with no default' do
      upload(svg('<!ATTLIST svg onload CDATA #IMPLIED>', shape))

      expect(response.body).not_to include(refusal)
    end
  end

  describe 'a file with harmless entities' do
    # A `desc` element holds the text, because the thumbnail step needs a font to draw a `text`
    # element.
    let(:shape_with_description) { '<desc>&x;</desc><rect width="10" height="10"/>' }

    it 'accepts an entity that expands to text' do
      upload(svg('<!ENTITY x "hello">', shape_with_description))

      expect(response.body).not_to include(refusal)
    end

    it 'accepts an entity that expands to a shape' do
      upload(svg(%q(<!ENTITY x "<rect width='10' height='10'/>">), '&x;'))

      expect(response.body).not_to include(refusal)
    end

    it 'accepts an entity whose text shows an escaped script tag' do
      upload(svg('<!ENTITY x "&lt;script&gt;">', shape_with_description))

      expect(response.body).not_to include(refusal)
    end

    it 'accepts the namespace entities that Adobe Illustrator writes' do
      doctype_id = 'PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd" '
      upload(svg('<!ENTITY ns_ai "http://ns.adobe.com/AdobeIllustrator/10.0/">',
                 '<g xmlns:i="&ns_ai;" i:extraneous="self"><rect width="10" height="10"/></g>',
                 doctype_id: doctype_id))

      expect(response.body).not_to include(refusal)
    end
  end
end
