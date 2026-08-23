# frozen_string_literal: true

RSpec.describe CamaleonCms::TermTaxonomyDecorator do
  describe '#the_title' do
    it 'HTML-escapes the taxonomy name to prevent stored XSS in raw sinks (breadcrumb, nav menu)' do
      post_type = create(:post_type, name: '<img src=x onerror=alert(1)>')

      title = post_type.decorate.the_title

      expect(title).to include('&lt;img')
      expect(title).not_to include('<img src=x onerror')
    end

    it 'preserves plain-text names unchanged' do
      post_type = create(:post_type, name: 'My Section')

      expect(post_type.decorate.the_title).to eq('My Section')
    end
  end

  # Built by interpolation and rendered through `raw` at admin/search.html.erb, like
  # PostDecorator#the_status. Only I18n strings reach it, so the output must not move.
  describe '#the_status' do
    it 'renders an active taxonomy exactly as before' do
      post_type = create(:post_type, status: '1')

      expect(post_type.decorate.the_status).to eq("<span class='label label-success'> Activated </span>")
    end

    it 'renders an inactive taxonomy exactly as before' do
      post_type = create(:post_type, status: '0')

      expect(post_type.decorate.the_status).to eq("<span class='label label-default'> Not Active </span>")
    end

    it 'returns a SafeBuffer' do
      post_type = create(:post_type, status: '1')

      expect(post_type.decorate.the_status).to be_a(ActiveSupport::SafeBuffer)
    end
  end
end
