# frozen_string_literal: true

RSpec.describe CamaleonCms::CamaleonHelper, type: :helper do
  describe '#cama_pluralize_text' do
    # `SafeBuffer#pluralize` returns a plain String, so the safe flag is gone before the call site
    # can compose with it. The helper propagates the safeness it was given -- and only that.
    it 'keeps a safe input safe' do
      result = helper.cama_pluralize_text('Ben &amp; Jerry Cake'.html_safe)

      expect(result).to eq('Ben &amp; Jerry Cakes')
      expect(result).to be_html_safe
    end

    it 'leaves an unsafe input unsafe' do
      result = helper.cama_pluralize_text('<b>x</b>')

      expect(result).to eq('<b>x</b>s')
      expect(result).not_to be_html_safe
    end

    it 'returns nil for nil' do
      expect(helper.cama_pluralize_text(nil)).to be_nil
    end
  end

  describe '#cama_t' do
    # The helper resolves a key in the current locale with the English text as the default, so a key
    # only en.yml carries still renders under another admin language. The fallback is looked up with
    # the caller's lookup options and without the interpolation values, so it is the translation the
    # caller named and is interpolated exactly once; the caller's options hash is left untouched.
    before do
      # I18n templates, not format strings, hence the template tokens.
      translations = { deep: 'scoped EN %{n}', named: 'key %{key} refused', a: 'A EN', b: 'B EN' } # rubocop:disable Style/FormatStringToken
      I18n.backend.store_translations(:en, cama_t_spec: translations)
      I18n.locale = :de
    end

    it 'falls back to the scoped English text when the caller passes scope:' do
      expect(helper.cama_t('deep', scope: 'cama_t_spec', n: 1)).to eq('scoped EN 1')
    end

    it 'raises for a key missing in every locale when the caller passes raise: true' do
      expect { helper.cama_t('cama_t_spec.nowhere', raise: true) }.to raise_error(I18n::MissingTranslationData)
    end

    it 'inserts a value carrying a placeholder token verbatim, without raising' do
      expect(helper.cama_t('cama_t_spec.named', key: 'meta[_%{x}]')).to eq('key meta[_%{x}] refused') # rubocop:disable Style/FormatStringToken
    end

    it 'leaves the options hash the caller passed untouched' do
      options = { n: 1 }

      expect(helper.cama_t('cama_t_spec.a', options)).to eq('A EN')
      expect(helper.cama_t('cama_t_spec.b', options)).to eq('B EN')
      expect(options).to eq({ n: 1 })
    end
  end

  describe '#cama_sitemap_cats_generator' do
    let(:site) { CamaleonCms::Site.first }
    let(:post_type) { site.post_types.find_by(slug: 'post') }
    let(:categories) { post_type.categories }

    it 'renders the category tree with no skip config at all' do
      expect { helper.cama_sitemap_cats_generator(categories) }.not_to raise_error
    end

    it 'ignores a non-hash skip config' do
      expect { helper.cama_sitemap_cats_generator(categories, 'nonsense') }.not_to raise_error
    end

    # An on_render_sitemap hook writing r[:skip_cat_ids] = nil used to win the merge and hand the
    # generator the nil the defaults exist to prevent -- the same nil.include? crash /sitemap.html
    # was fixed for.
    it 'survives a hook that nils out a skip list' do
      expect { helper.cama_sitemap_cats_generator(categories, { skip_cat_ids: nil, skip_post_ids: nil }) }
        .not_to raise_error
    end

    it 'still honours a skip list the hook did supply' do
      skipped = categories.first

      output = helper.cama_sitemap_cats_generator(categories, { skip_cat_ids: [skipped.id] })

      expect(output).not_to include(skipped.name)
    end
  end
end
