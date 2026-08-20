# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin login page locale', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:spanish_log_in) { I18n.t('camaleon_cms.admin.button.log_in', locale: :es) }
  let(:english_log_in) { I18n.t('camaleon_cms.admin.button.log_in', locale: :en) }

  before do
    current_site.set_meta('languages_site', %w[es en])
    I18n.locale = I18n.default_locale
  end

  after { I18n.locale = I18n.default_locale }

  it 'renders the login page in the site first language' do
    get '/admin/login'

    expect(response.body).to include(spanish_log_in)
  end

  it 'honors ?locale= when the site offers it' do
    get '/admin/login', params: { locale: 'en' }

    expect(response.body).to include(english_log_in)
    expect(response.body).not_to include(spanish_log_in)
  end

  it 'falls back without an error when ?locale= is not offered by the site' do
    current_site.set_meta('languages_site', %w[es])

    get '/admin/login', params: { locale: 'de' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(spanish_log_in)
  end

  it 'ignores a non-scalar ?locale= instead of erroring' do
    get '/admin/login', params: { locale: ['en'] }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(spanish_log_in)
  end

  it 'ignores the frontend session language' do
    get '/', params: { cama_set_language: 'en' }

    get '/admin/login'

    expect(response.body).to include(spanish_log_in)
  end
end
