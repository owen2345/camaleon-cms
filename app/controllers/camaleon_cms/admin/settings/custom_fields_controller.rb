module CamaleonCms
  module Admin
    module Settings
      class CustomFieldsController < CamaleonCms::Admin::SettingsController
        add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.custom_fields'), :cama_admin_settings_custom_fields_path
        before_action :set_custom_field_group, only: %i[show edit update destroy]
        before_action :set_post_data, only: %i[create update]

        def index
          @field_groups = current_site.custom_field_groups.visible_group.eager_load(:site)
          @field_groups = @field_groups.where(object_class: params[:c]) if params[:c].present?
          @field_groups = @field_groups.where(objectid: params[:id]) if params[:id].present?
          @field_groups = @field_groups.paginate(page: params[:page], per_page: current_site.admin_per_page)
        end

        def get_items
          @key = params[:key]
          render partial: 'get_items', layout: false
        end

        def show; end

        def edit
          add_breadcrumb I18n.t('camaleon_cms.admin.button.edit')
          render 'form'
        end

        def update
          if @field_group.update(@post_data) && _save_fields(@field_group)
            redirect_to action: :edit, id: @field_group.id
          else
            render 'form'
          end
        end

        def new
          add_breadcrumb I18n.t('camaleon_cms.admin.button.new')
          @field_group ||= current_site.custom_field_groups.new
          render 'form'
        end

        # create a new custom field group
        def create
          @field_group = current_site.custom_field_groups.new(@post_data)
          if @field_group.save && _save_fields(@field_group)
            redirect_to action: :edit, id: @field_group.id
          else
            new
          end
        end

        # destroy a custom field group
        def destroy
          @field_group.destroy
          flash[:notice] = t('camaleon_cms.admin.custom_field.message.deleted', default: 'Custom Field Group Deleted.')
          redirect_to action: :index
        end

        # reorder custom fields group
        def reorder
          params[:values].to_a.each_with_index do |value, index|
            current_site.custom_field_groups.find(value).update_column('field_order', index)
          end
          json = { size: params[:values].size }
          render json: json
        end

        def list
          p = params.permit(:post_type, :post_id, categories: [])
          args = {}
          if p[:post_id].present?
            post = @current_site.the_post(p[:post_id].to_i)
            post.update_categories(p[:categories])
          else
            post = CamaleonCms::Post.new
            post.taxonomy_id = p[:post_type].to_i
            args[:cat_ids] = p[:categories]
          end
          render partial: 'camaleon_cms/admin/settings/custom_fields/render',
                 locals: { record: post, field_groups: post.get_field_groups(args),
                           show_shortcode: true }
        end

        private

        def set_post_data
          @post_data = params.require(:custom_field_group).permit!
          @post_data[:object_class], @post_data[:objectid] = @post_data.delete(:assign_group).split(',')
          @caption = @post_data.delete(:caption)
        end

        def set_custom_field_group
          @field_group = current_site.custom_field_groups.find(params[:id])
        rescue StandardError
          flash[:error] = t('camaleon_cms.admin.custom_field.message.custom_group_error')
          redirect_to cama_admin_path
        end

        # return boolean: true if all fields were saved successfully
        def _save_fields(group)
          errors_saved, _all_fields = group.add_fields(params[:fields] ? params.require(:fields).permit! : {},
                                                       params[:field_options] ? params.require(:field_options).permit! : {})
          group.set_option('caption', @caption)
          if errors_saved.present?
            flash[:error] = "<b>#{t('camaleon_cms.errors_found_msg', default: 'Several errors were found, please check.')}</b><br>#{errors_saved.map do |field|
                                                                                                                                      "#{field.name}: " + field.errors.messages.map do |k, v|
                                                                                                                                                            "#{k.to_s.titleize}: #{v.join('|')}"
                                                                                                                                                          end.join(', ').to_s
                                                                                                                                    end.join('<br>')}"
          else
            flash[:notice] = t('camaleon_cms.admin.custom_field.message.custom_updated')
          end
          true
        end
      end
    end
  end
end
