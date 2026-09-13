# frozen_string_literal: true

# The refusal messages embed the submitted key name. Under an admin language other than English (whose
# locale file lacks these keys), the message resolves through the English fallback. That fallback was
# interpolated with the vars and then interpolated again, so a submitted key carrying a `%{...}` token
# (e.g. `meta[_%{x}]`, which the field-name rule refuses) raised I18n::MissingInterpolationArgument --
# a 500 instead of the refusal. The fallback must be interpolated once.
RSpec.describe 'Security: refusal message under a non-English admin locale', type: :request do
  include_context 'with the post editor'

  # A key whose name carries a format token; a literal key, not a template.
  let(:reserved_key) { '_%{x}' } # rubocop:disable Style/FormatStringToken
  let(:expected_message) do
    "meta[#{reserved_key}] is not a field name Camaleon CMS accepts: use letters, digits, underscores, dashes and dots."
  end

  before { current_site.set_option('_admin_theme', 'es') } # admin language with no translation for the refusal keys

  after { I18n.locale = :en }

  it 'refuses a placeholder-bearing key without raising' do
    sign_in_as(editor, site: current_site)

    update_published_post(meta: { reserved_key => '1' })

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(expected_message)
  end
end
