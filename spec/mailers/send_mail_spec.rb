require 'rails_helper'

describe "CamaleonCms::HtmlMailer" do
  describe 'empty content' do
    get_current_test_site()
    let(:mail) { CamaleonCms::HtmlMailer.sender('test@gmail.com', "test") }

    it 'renders the subject' do
      expect(mail.subject).to eql('test')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eql(['test@gmail.com'])
    end

    it 'renders the sender email' do
      expect(mail.from).to eql(['owenperedo@gmail.com'])
    end

    it 'html layout text' do
      expect(mail.body.encoded).to match('Visit Site')
    end
  end

  describe 'custom content' do
    get_current_test_site()
    let(:mail) { CamaleonCms::HtmlMailer.sender('test@gmail.com', "test", content: 'custom content', cc_to: ['a@gmail.com', 'b@gmail.com']) }

    it 'renders the sender email' do
      expect(mail.cc).to eql(['a@gmail.com', 'b@gmail.com'])
    end

    it 'custom content' do
      expect(mail.body.encoded).to match('custom content')
    end
  end
end