class Plugins::PostClone::AdminController < Apps::PluginsAdminController
  def clone
    i = [:term_relationships, :metas]
    i << :field_values if @plugin.get_field_value("plugin_clone_custom_fields")
    post = current_site.posts.find(params[:id])
    clone = post.deep_clone(include: i)
    clone.post_type = post.post_type
    slugs = clone.slug.translations
    titles = clone.title.translations
    slugs.each do |k, v|
      slugs[k] = current_site.get_valid_post_slug(v)
      titles[k] = "#{v} (clone)"
    end
    if slugs.empty?
      clone.slug = current_site.get_valid_post_slug(clone.slug)
      clone.title << " (clone)"
    else
      clone.slug = slugs.to_translate
      clone.title = titles.to_translate
    end
    clone.save!
    flash[:notice] = "#{t('plugin.post_clone.message.content_cloned')}"
    redirect_to clone.decorate.the_edit_url
  end

  def settings

  end

  def settings_save
    @plugin.set_field_values(params[:field_options])
    flash[:notice] = "#{t('plugin.post_clone.message.settings_saved')}"
    redirect_to action: :settings
  end
end