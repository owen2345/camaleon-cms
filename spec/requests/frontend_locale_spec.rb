# frozen_string_literal: true

require 'rails_helper'

# The frontend resolves its locale from ?locale=, the session language (set via
# ?cama_set_language=), and the site's languages. A non-scalar value for either
# param must degrade to the fallback chain instead of crashing the request.
RSpec.describe 'Frontend locale resolution', type: :request do
  init_site

  before { I18n.locale = I18n.default_locale }

  after { I18n.locale = I18n.default_locale }

  it 'ignores a non-scalar ?locale= instead of erroring' do
    get '/', params: { locale: ['en'] }

    expect(response).to have_http_status(:ok)
  end

  it 'ignores a non-scalar ?cama_set_language= instead of erroring' do
    get '/', params: { cama_set_language: ['en'] }

    expect(response).to have_http_status(:ok)
  end

  it 'still honors a scalar ?locale= the site offers' do
    get '/', params: { locale: 'en' }

    expect(response).to have_http_status(:ok)
  end
end
