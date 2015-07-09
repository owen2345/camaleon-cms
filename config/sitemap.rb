require 'uri'
h = PluginRoutes.system_info["base_domain"]

Site.all.each do |site|
  site = site.decorate
  folder "sitemaps/#{site.slug}"
  # host site.slug.include?(".") ? site.slug : "#{site.slug}.#{h}"
  host site.the_url.to_s.parse_domain

  langs = site.get_languages

  sitemap :site do
    url root_url, priority: 1.0, change_freq: "daily"

    langs.each_with_index{|l, index| url site.the_url(locale: index==0?nil:l), last_mod: site.updated_at, priority: 0.9 }
    url sitemap_url
  end


  sitemap_for site.posts.public_posts, name: :published_posts do |post|
    post = post.decorate
    langs.each_with_index{|l, index| url post.the_url(locale: index==0?nil:l), last_mod: post.updated_at, priority: 0.7 }
  end

  sitemap_for site.full_categories.no_empty, name: :categories do |cat|
    cat = cat.decorate
    langs.each_with_index{|l, index| url cat.the_url(locale: index==0?nil:l), last_mod: cat.updated_at, priority: 0.5 }
  end

  sitemap_for site.post_types, name: :groups do |ptype|
    ptype = ptype.decorate
    langs.each_with_index{|l, index| url ptype.the_url(locale: index==0?nil:l), last_mod: ptype.updated_at, priority: 0.3 }
  end

  sitemap_for site.post_tags, name: :tags do |ptag|
    ptag = ptag.decorate
    langs.each_with_index{|l, index| url ptag.the_url(locale: index==0?nil:l), last_mod: ptag.updated_at, priority: 0.2 }
  end

  # hooks
  c = ApplicationController.new
  c.instance_eval do
    @current_site = site
    @_hooks_skip = []
  end

  # sample: sitemap :site2 do \n  url root_url  \n   end
  r = {site: site, eval: ""}; c.hooks_run("sitemap", r)
  instance_eval(r[:eval]) if r[:eval].present?

  ping_with "http://#{host}/sitemap.xml"
end