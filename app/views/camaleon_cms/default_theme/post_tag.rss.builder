xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title @post_tag.the_title
    xml.description @post_tag.the_excerpt
    xml.link @post_tag.the_url
    xml.guid @post_tag.the_id
    xml.items @posts.size

    @posts.decorate.each do |post|
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
