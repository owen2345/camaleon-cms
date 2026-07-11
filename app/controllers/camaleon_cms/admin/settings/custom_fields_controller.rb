module CamaleonCms
  module Admin
    module Settings
      class CustomFieldsController < CamaleonCms::Admin::SettingsController
        add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.custom_fields'), :cama_admin_settings_custom_fields_path

        before_action :validate_role, only: %i[create update destroy]
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
            current_site.custom_field_groups.find(value)
                        .update_column(:field_order, index) # rubocop:disable Rails/SkipsModelValidations
          end
          json = { size: params[:values].size }
          render json: json
        end

        def list
          p = params.permit(:post_type, :post_id)
          cat_ids = current_site.full_categories.where(id: params[:categories]).pluck(:id)
          if p[:post_id].present? && (post = current_site.the_post(p[:post_id].to_i)).present?
            post.update_categories(cat_ids)
          else
            post = CamaleonCms::Post.new
            post.taxonomy_id = current_site.the_post_type(p[:post_type].to_i)&.id
          end
          args = { cat_ids: cat_ids }
          render partial: 'camaleon_cms/admin/settings/custom_fields/render',
                 locals: { record: post, field_groups: post.get_field_groups(args),
                           show_shortcode: true }
        end

        private

        def set_post_data
          @post_data = params.require(:custom_field_group).permit(:name, :description, :assign_group, :caption)
          @post_data[:object_class], @post_data[:objectid] = @post_data.delete(:assign_group).to_s.split(',')
          @caption = @post_data.delete(:caption)
        end

        def validate_role
          authorize! :manage, :custom_fields
        end

        def set_custom_field_group
          @field_group = current_site.custom_field_groups.find(params[:id])
        rescue StandardError
          flash[:error] = t('camaleon_cms.admin.custom_field.message.custom_group_error')
          redirect_to cama_admin_path
        end

        def permitted_fields
          return {} if params[:fields].blank?

          params.require(:fields).permit(params[:fields].keys.index_with do
            %i[id name slug description field_order]
          end).to_h
        end

        def permitted_field_options
          return {} if params[:field_options].blank?

          params.require(:field_options).permit(params[:field_options].keys.index_with do
            [:field_key, :multiple, :required, :translate, :default_value, :dimension, :width, :height, :class,
             :placeholder, { default_values: [], multiple_options: %i[title value default] }]
          end).to_h
        end

        # return boolean: true if all fields were saved successfully
        def _save_fields(group)
          errors_saved, _all_fields = group.add_fields(permitted_fields, permitted_field_options)
          group.set_option('caption', @caption)
          if errors_saved.present?
            errors_found_msg = t('camaleon_cms.errors_found_msg', default: 'Several errors were found, please check.')
            errors_saved_all_text = errors_saved.map do |field|
              "#{field.name}: " + field.errors.messages.map do |k, v|
                "#{k.to_s.titleize}: #{v.join('|')}"
              end.join(', ').to_s
            end.join('<br>')
            flash[:error] = "<b>#{errors_found_msg}</b><br>#{errors_saved_all_text}"
            false
          else
            flash[:notice] = t('camaleon_cms.admin.custom_field.message.custom_updated')
          end
        end
      end
    end
  end
end
