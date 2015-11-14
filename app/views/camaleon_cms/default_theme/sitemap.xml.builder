xml.instruct! :xml, :version => "1.0"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  current_site.get_languages.each_with_index do |lang, index| lang = (index == 0 ? nil : lang);
    xml.url do
      xml.loc current_site.the_url(locale: lang)
      xml.lastmod current_site.updated_at.to_date
      xml.changefreq "daily"
      xml.priority "1.0"
    end

    for post in current_site.the_posts.decorate do
      next if @r[:skip_post_ids].include?(post.id)
      xml.url do
        xml.loc post.the_url(locale: lang)
        xml.lastmod post.updated_at.to_date
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end

    for cat in current_site.full_categories.no_empty.decorate do
      next if @r[:skip_cat_ids].include?(cat.id)
      xml.url do
        xml.loc cat.the_url(locale: lang)
        xml.lastmod cat.updated_at.to_date
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end

    for ptype in current_site.post_types.decorate do
      next if @r[:skip_posttype_ids].include?(ptype.id)
      xml.url do
        xml.loc ptype.the_url(locale: lang)
        xml.lastmod ptype.updated_at.to_date
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end

    for tag in current_site.post_tags.decorate do
      next if @r[:skip_tag_ids].include?(tag.id)
      xml.url do
        xml.loc tag.the_url(locale: lang)
        xml.lastmod tag.updated_at.to_date
        xml.changefreq "monthly"
        xml.priority "0.5"
      end
    end
  end

  @r[:custom].each do |key, item|
    xml.url do
      xml.loc item[:url]
      xml.lastmod item[:lastmod] || Date.today.to_s
      xml.changefreq item[:changefreq] || "monthly"
      xml.priority item[:priority] || "0.5"
    end
  end
end