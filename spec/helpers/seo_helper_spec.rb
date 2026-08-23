# frozen_string_literal: true

describe CamaleonCms::Frontend::SeoHelper do
  let(:host) { request_env['HTTP_HOST'] }
  let(:request_env) { ActionDispatch::TestRequest.__send__(:default_env) }
  let(:url_scheme) { request_env['rack.url_scheme'] }

  let!(:site) { create(:site, slug: host).decorate }

  describe '#cama_the_seo' do
    context 'with :canonical hash key value returned' do
      context 'when no seo_canonical is specified for the site' do
        it 'returns nil' do
          result = helper.cama_the_seo

          expect(result[:canonical]).to be_nil
        end
      end

      context 'when seo_canonical is specified for the site and for the current locale (:en by default)' do
        before { site.set_option('seo_canonical', "<!--:en-->https://#{host}/<!--:--><!--:es--><!--:-->") }

        it 'returns the canonical url for the default language' do
          result = helper.cama_the_seo

          expect(result[:canonical]).to eql("https://#{host}/")
        end
      end

      context 'when seo_canonical is specified for the site but not for the current locale' do
        before { site.set_option('seo_canonical', "<!--:en-->https://#{host}/<!--:--><!--:es--><!--:-->") }

        it 'returns an empty string as canonical url' do
          I18n.locale = :es
          result = helper.cama_the_seo

          expect(result[:canonical]).to be_empty
        end
      end

      context 'when seo_canonical is specified for the site and for the current, not default, locale' do
        before do
          site.set_option('seo_canonical', "<!--:en-->https://#{host}/<!--:--><!--:es-->https://#{host}/es<!--:-->")
        end

        it 'returns the canonical url for the current language' do
          I18n.locale = :es
          result = helper.cama_the_seo

          expect(result[:canonical]).to eql("https://#{host}/es")
        end
      end
    end

    context 'when no site languages are specified' do
      it "doesn't returns the an alternate hreflang" do
        result = helper.cama_the_seo

        expect(result[:alternate]).to eql(
          [{ href: "#{url_scheme}://#{host}/rss", type: 'application/rss+xml' }]
        )
      end
    end

    context 'when there are site languages specified' do
      before { site.set_meta('languages_site', [I18n.default_locale, :es]) }

      it 'returns an array of alternates for all the languages' do
        I18n.locale = :es
        result = helper.cama_the_seo

        expect(result[:alternate]).to eql(
          [{ href: "#{url_scheme}://#{host}/rss", type: 'application/rss+xml' },
           { href: "#{url_scheme}://#{host}/", hreflang: :en },
           { href: "#{url_scheme}://#{host}/es", hreflang: :es }]
        )
      end
    end

    # Regression M20: the profile branch reads visited_user for the avatar/name/slogan; a plugin front
    # controller that sets the legacy @user ivar (the 2.9.2 way) must still back it when
    # CurrentRequest.frontend_user is unset.
    context 'when visiting a profile (regression M20)' do
      let(:legacy_user) do
        instance_double(CamaleonCms::UserDecorator,
                        the_avatar: '/legacy.png', the_name: 'Legacy', the_slogan: 'legacy bio')
      end

      before { CurrentRequest.frontend_visited_profile = true }

      it 'builds the profile SEO from a plugin-set legacy @user ivar' do
        helper.instance_variable_set(:@user, legacy_user)

        result = helper.cama_the_seo

        expect(result[:og][:title]).to eql("#{site.the_title} | Legacy")
        expect(result[:og][:description]).to eql('legacy bio')
        expect(result[:og][:image]).to eql('/legacy.png')
      end

      it 'prefers CurrentRequest.frontend_user over the legacy ivar' do
        CurrentRequest.frontend_user = instance_double(
          CamaleonCms::UserDecorator, the_avatar: '/current.png', the_name: 'Current', the_slogan: 'current bio'
        )
        helper.instance_variable_set(:@user, legacy_user)

        result = helper.cama_the_seo

        expect(result[:og][:title]).to eql("#{site.the_title} | Current")
      end
    end
  end
end
