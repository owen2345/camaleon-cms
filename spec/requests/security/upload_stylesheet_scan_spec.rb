# frozen_string_literal: true

# The upload scan refused the `link` and `style` elements, which load a stylesheet. It accepted an
# `xml-stylesheet` processing instruction, which loads one too. With the type `text/xsl`, the
# instruction makes a browser with XSLT run a stylesheet from the same origin. A stylesheet is a
# program: it can give an element a handler whose name it builds when it runs. So no scan of the
# stylesheet file can find that handler.
RSpec.describe 'Upload scan of stylesheets in an XML file', type: :request do
  init_site

  include_context 'with a media-only uploader'

  let(:xslt) { 'http://www.w3.org/1999/XSL/Transform' }
  let(:shape) { '<rect width="10" height="10"/>' }

  def svg(body, prolog: '', root_attributes: '')
    %(<?xml version="1.0"?>#{prolog}) +
      %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" #{root_attributes}>#{body}</svg>)
  end

  describe 'an xml-stylesheet processing instruction' do
    %w[.svg .xml .xhtml].each do |extension|
      it "refuses the instruction for a CSS file in a #{extension} file" do
        upload(svg(shape, prolog: '<?xml-stylesheet type="text/css" href="https://evil.example/x.css"?>'),
               extension: extension)

        expect(response.body).to include(refusal)
      end
    end

    it 'refuses the instruction for an XSL file' do
      upload(%(<?xml version="1.0"?><?xml-stylesheet type="text/xsl" href="x.xsl"?><data>text</data>),
             extension: '.xml')

      expect(response.body).to include(refusal)
    end

    it 'refuses the instruction in the DTD, after an entity declaration' do
      doctype = '<!DOCTYPE svg [<!ENTITY x "y"><?xml-stylesheet type="text/css" href="x.css"?>]>'
      upload(svg(shape, prolog: doctype))

      expect(response.body).to include(refusal)
    end

    it 'accepts another processing instruction' do
      upload(svg(shape, prolog: '<?editor version="2"?>'))

      expect(response.body).not_to include(refusal)
    end
  end

  describe 'a file that declares the XSLT namespace' do
    # A stylesheet with no `xsl:template`: the `xsl:version` attribute makes its root element the
    # template. It builds the `onerror` name when it runs.
    let(:stylesheet) do
      <<~XML
        <?xml version="1.0"?>
        <html xsl:version="1.0" xmlns:xsl="#{xslt}" xmlns="http://www.w3.org/1999/xhtml">
          <body>
            <xsl:element name="img">
              <xsl:attribute name="{concat('o','nerror')}">alert(1)</xsl:attribute>
            </xsl:element>
          </body>
        </html>
      XML
    end

    %w[.xsl .xslt .xml .xhtml].each do |extension|
      it "refuses a stylesheet that builds a handler name in a #{extension} file" do
        upload(stylesheet, extension: extension)

        expect(response.body).to include(refusal)
      end
    end

    it 'refuses the namespace that an entity gives' do
      upload(%(<?xml version="1.0"?><!DOCTYPE t [<!ENTITY n "#{xslt}">]><t:transform xmlns:t="&n;" version="1.0"/>),
             extension: '.xsl')

      expect(response.body).to include(refusal)
    end

    it 'refuses the namespace that an attribute default of the DTD gives' do
      upload(<<~XML, extension: '.xsl')
        <?xml version="1.0"?>
        <!DOCTYPE html [<!ATTLIST html xmlns:xsl CDATA "#{xslt}">]>
        <html><body><xsl:element name="img"/></body></html>
      XML

      expect(response.body).to include(refusal)
    end

    it 'refuses an SVG file that declares the namespace and does not use it' do
      upload(svg(shape, root_attributes: %(xmlns:xsl="#{xslt}")))

      expect(response.body).to include(refusal)
    end

    it 'accepts an SVG file that declares another namespace' do
      upload(svg(shape, root_attributes: 'xmlns:xlink="http://www.w3.org/1999/xlink"'))

      expect(response.body).not_to include(refusal)
    end
  end
end
