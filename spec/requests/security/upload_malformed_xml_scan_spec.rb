# frozen_string_literal: true

# The upload scan parsed a file in an XML format in the recover mode of the parser. So it gave a
# verdict on the tree that the parser built from a file with a fatal XML error. A browser does not
# build that tree. The scan now refuses such a file.
RSpec.describe 'Upload scan of a file that is not well-formed XML', type: :request do
  init_site

  include_context 'with a media-only uploader'

  def svg(body)
    %(<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">#{body}</svg>)
  end

  %w[.svg .xml .xhtml .xsl].each do |extension|
    it "refuses a #{extension} file with an element that has no end tag" do
      upload(svg('<g><rect width="10" height="10"/>'), extension: extension)

      expect(response.body).to include(refusal)
    end
  end

  it 'refuses a file with text after the root element' do
    upload("#{svg('<rect width="10" height="10"/>')}text")

    expect(response.body).to include(refusal)
  end

  it 'refuses a file with an entity that it does not declare' do
    upload(svg('<desc>&nbsp;</desc><rect width="10" height="10"/>'))

    expect(response.body).to include(refusal)
  end

  it 'refuses a file with an attribute that an element has two times' do
    upload(svg('<rect width="10" width="20" height="10"/>'))

    expect(response.body).to include(refusal)
  end

  it 'accepts a well-formed file' do
    upload(svg('<rect width="10" height="10"/>'))

    expect(response.body).not_to include(refusal)
  end

  # The XHTML DTD declares `nbsp`. The parser does not load that DTD, so it reports no fatal error
  # for the reference.
  it 'accepts an XHTML file that uses an entity of its public DTD' do
    doctype = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" ' \
              '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'
    upload(%(#{doctype}<html xmlns="http://www.w3.org/1999/xhtml"><body><p>a&nbsp;b</p></body></html>),
           extension: '.xhtml')

    expect(response.body).not_to include(refusal)
  end
end
