# frozen_string_literal: true

# A trial draw of the routes that fails raises CamaleonCms::RouteDrawError. An admin request answers
# it as a refused save, with the error of the route file in the message.
RSpec.describe 'An admin request whose route draw fails', type: :request do
  init_site

  let(:admin) { create(:user, role: 'admin', site: @site) }
  let(:languages_url) { "http://#{@site.slug}/admin/settings/languages" }

  before do
    host! @site.slug
    sign_in_as(admin, site: @site)
  end

  # The save of the languages stores them, and then reloads the routes with no open transaction.
  it 'says that the routes stay as they were, for a change that is stored before the draw' do
    names = app_route_names
    break_the_routes

    post '/admin/settings/languages', params: { lang: %w[en es], admin_language: 'en' },
                                      headers: { 'HTTP_REFERER' => languages_url }

    expect(response).to redirect_to(languages_url)
    expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_routes_kept',
                                       error: 'ArgumentError: broken plugin routes'))
    expect(flash[:notice]).to be_nil
    expect(CamaleonCms::Site.find(@site.id).get_meta('languages_site')).to eq(%w[en es])
    expect(app_route_names).to eq(names)
  end

  it 'logs the error of the route file' do
    break_the_routes
    allow(Rails.logger).to receive(:error)
    expect(Rails.logger).to receive(:error).with(/the routes cannot be drawn.*ArgumentError: broken plugin routes/m)

    post '/admin/settings/languages', params: { lang: %w[en es], admin_language: 'en' },
                                      headers: { 'HTTP_REFERER' => languages_url }
  end

  # The flash shows its message as HTML, and an XHR reads the message as text.
  it 'escapes the text of the route file error in the flash, and not in the text for an XHR' do
    break_the_routes("raise ArgumentError, '<b>broken</b>'")
    options = { params: { lang: %w[en es], admin_language: 'en' }, headers: { 'HTTP_REFERER' => languages_url } }

    post '/admin/settings/languages', **options
    expect(flash[:error]).to include('ArgumentError: &lt;b&gt;broken&lt;/b&gt;')

    post '/admin/settings/languages', **options, xhr: true
    expect(response.body).to include('ArgumentError: <b>broken</b>')
  end

  # The delete of a site removes its media folder, and a rollback does not bring the folder back. So
  # the site checks the routes before the first step of the delete.
  it 'does not delete a site or its media folder when the routes cannot be drawn' do
    other_site = create(:site)
    media_dir = File.join(Rails.public_path, 'media', other_site.upload_directory_name)
    FileUtils.mkdir_p(media_dir)
    break_the_routes

    delete "/admin/settings/sites/#{other_site.id}", headers: { 'HTTP_REFERER' => languages_url }

    expect(response).to redirect_to(languages_url)
    expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_change_not_saved',
                                       error: 'ArgumentError: broken plugin routes'))
    expect(CamaleonCms::Site.exists?(other_site.id)).to be(true)
    expect(other_site.post_types.count).to be_positive
    expect(Dir.exist?(media_dir)).to be(true)
  ensure
    FileUtils.rm_rf(media_dir) if media_dir
  end

  # A GET request submits no form, and a redirect leads to a page that fails the same way.
  it 'raises the error again for a GET request' do
    error = CamaleonCms::RouteDrawError.new(ArgumentError.new('broken plugin routes'), in_transaction: false)
    allow_any_instance_of(CamaleonCms::Admin::SettingsController).to receive(:languages).and_raise(error)

    expect { get '/admin/settings/languages' }.to raise_error(CamaleonCms::RouteDrawError)
  end
end
