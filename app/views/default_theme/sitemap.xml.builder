xml.instruct! :xml, :version => "1.0"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  current_site.get_languages.each_with_index do |lang, index| lang = (index == 0 ? nil : lang);
    xml.url do
      xml.loc current_site.the_url(locale: lang)
      xml.lastmod current_site.updated_at
      xml.changefreq "daily"
      xml.priority "1.0"
    end

    for post in current_site.the_posts.decorate do
      xml.url do
        xml.loc post.the_url(locale: lang)
        xml.lastmod post.updated_at
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end

    for cat in current_site.full_categories.no_empty.decorate do
      xml.url do
        xml.loc cat.the_url(locale: lang)
        xml.lastmod cat.updated_at
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end

    for ptype in current_site.post_types.decorate do
      xml.url do
        xml.loc ptype.the_url(locale: lang)
        xml.lastmod ptype.updated_at
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end

    for tag in current_site.post_tags.decorate do
      xml.url do
        xml.loc tag.the_url(locale: lang)
        xml.lastmod tag.updated_at
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end
  end

end