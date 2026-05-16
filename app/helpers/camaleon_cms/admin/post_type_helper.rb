module CamaleonCms
  module Admin
    module PostTypeHelper
      # taxonomy -> (categories || post_tags)
      def post_type_html_inputs(post_type, taxonomy = 'categories', name = 'categories', type = 'checkbox',
                                values = [], class_cat = 'categorychecklist', required = false)
        categories = post_type.send(taxonomy)
        categories = categories.eager_load(:children, :post_type_parent, :parent) if %w[categories
                                                                                        children].include?(taxonomy)
        post_type_taxonomy_html_(categories, taxonomy, name, type, values, class_cat, required)
      end

      def post_type_status(status, color = 'default')
        content_tag(:span, status, class: "label label-#{color} label-form")
      end

      # taxonomies ->  (categories || post_tags)
      def post_type_list_taxonomy(taxonomies, color = 'primary')
        safe_join(taxonomies.decorate.map do |f|
          link_to(
            cama_admin_post_type_taxonomy_posts_path(@post_type.id, f.taxonomy, f.id), class: 'cama_ajax_request'
          ) do
            content_tag(:span, f.the_title, class: "label label-#{color} label-form")
          end
        end, ' ')
      end

      # sort array of posts to build post's tree
      # skip_non_parent_posts: don't include post's where root post doesn't exist
      # internal control for recursive items
      def cama_hierarchy_post_list(posts_list, parent_id = nil, skip_non_parent_posts = false)
        res = []
        @_cama_hierarchy_post_list_no_parent ||= posts_list.clone
        posts_list.each do |element|
          next unless element.post_parent.to_s == parent_id.to_s

          res << element
          @_cama_hierarchy_post_list_no_parent.delete_item(element)
          res += cama_hierarchy_post_list(posts_list, element.id)
        end

        if parent_id.blank? && !skip_non_parent_posts
          @_cama_hierarchy_post_list_no_parent.each do |element|
            element.show_title_with_parent = true
            res << element
            res += cama_hierarchy_post_list(posts_list, element.id)
          end
        end
        res
      end

      private

      def post_type_taxonomy_html_(categories, taxonomy = 'categories', name = 'categories', type = 'checkbox',
                                   values = [], class_cat = '', required = false)
        if categories.count < 1
          taxonomy == 'categories' ? t('camaleon_cms.admin.table.categories') : t('camaleon_cms.admin.table.tags')
          return t('camaleon_cms.admin.post_type.message.no_created_html', taxonomy: taxonomy)
        end

        content_tag(:ul, class: class_cat) do
          items = categories.decorate.map do |f|
            content_tag(:li) do
              is_checked = Array(values).map(&:to_s).include?(f.id.to_s)
              input_options = {
                class: (required ? 'required' : ''), data: { error_place: "#validation_error_list_#{name}" }
              }
              input_tag = if type == 'radio'
                            radio_button_tag("#{name}[]", f.id, is_checked, input_options)
                          else
                            check_box_tag("#{name}[]", f.id, is_checked, input_options)
                          end
              res = content_tag(:label, class: 'class_slug', data: { post_link_edit: f.the_edit_url }) do
                safe_join([input_tag, ' ', f.the_title.to_s, ' '])
              end
              res << post_type_html_inputs(f, 'children', name, type, values, 'children') if f.children.present?
              res
            end
          end
          safe_join(items)
        end + content_tag(:div, '', id: "validation_error_list_#{name}")
      end
    end
  end
end
