# Regression audit M21: #1177 dropped the caller-set @current_site branch from
# SiteHelper#current_site. Background senders (HtmlMailer, jobs) assign @current_site but had it
# ignored; on a multisite install, resolution then fell through to the request-based branch and
# raised NameError (no request in a mailer/job), so no mail was sent. These pin the restored
# precedence and the multisite mailer symptom.
describe CamaleonCms::SiteHelper do
  subject(:helper_object) { Class.new { include CamaleonCms::SiteHelper }.new }

  let(:site) { CamaleonCms::Site.first.decorate }

  before do
    CurrentRequest.reset
    # Force the multisite branch of #current_site (get_sites.size != 1), where the un-fixed code
    # dereferences `request`. No second DB row needed.
    allow(PluginRoutes).to receive(:get_sites).and_return([site, site])
  end

  after { CurrentRequest.reset }

  describe '#current_site with a caller-set @current_site and no request' do
    before { helper_object.instance_variable_set(:@current_site, site) }

    it 'returns the caller-set site instead of raising NameError on `request`' do
      expect { helper_object.current_site }.not_to raise_error
      expect(helper_object.current_site).to eq(site)
    end

    it 'writes it through to CurrentRequest.site' do
      helper_object.current_site
      expect(CurrentRequest.site).to eq(site)
    end
  end

  describe '#current_site precedence' do
    it 'prefers a caller-set @current_site over an already-memoized CurrentRequest.site' do
      # so an in-request deliver_now for another site resolves against @current_site, not the request's
      CurrentRequest.site = instance_double(CamaleonCms::SiteDecorator).as_null_object
      helper_object.instance_variable_set(:@current_site, site)
      expect(helper_object.current_site).to eq(site)
    end
  end

  describe '#current_site when no site matches the request' do
    # A site held in a global serves every request of a server process from one record and the options it
    # memoized, so the logged advice must not recommend $current_site.
    subject(:helper_object) do
      Class.new do
        include CamaleonCms::SiteHelper

        def request
          ActionDispatch::TestRequest.create('HTTP_HOST' => 'unmapped.example')
        end
      end.new
    end

    it 'logs domain-mapping advice without recommending the $current_site global' do
      messages = []
      allow(Rails.logger).to receive(:error) { |message| messages << message }

      expect(helper_object.current_site).to be_nil
      expect(messages).to contain_exactly(a_string_including('139779-examples/how.html'))
      expect(messages.first).not_to include('$current_site')
    end
  end

  describe 'HtmlMailer on a multisite install (real-world M21 symptom)' do
    it 'builds the message without raising when there is no request' do
      mail = CamaleonCms::HtmlMailer.sender('test@gmail.com', 'test', current_site: site.id,
                                                                      content: 'hi there')
      expect { mail.subject }.not_to raise_error
      expect(mail.subject).to eq('test')
      expect(mail.body.encoded).to match('hi there')
    end
  end
end
