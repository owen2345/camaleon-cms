xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do
  xml.channel do
    xml.title current_site.the_title
    xml.description current_site.the_excerpt
    xml.link current_site.the_url


    for post in current_site.the_contents.paginate(:page => params[:page], :per_page => current_site.front_per_page).decorate
      xml.item do
        xml.title post.the_title
        xml.description post.the_excerpt
        xml.pubDate post.the_created_at
        xml.upDate post.the_updated_at
        xml.link post.the_url
        xml.guid post.the_id
        xml.thumb post.the_thumb_url
      end
    end
  end
end