module CamaleonCms
  module Admin
    module Settings
      class PostTypesController < CamaleonCms::Admin::SettingsController
        before_action :set_post_type, only: %i[show edit update destroy]
        before_action :set_data_term, only: %i[create update]

        add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.content_groups'), :cama_admin_settings_post_types_path

        def index
          @post_types = current_site.post_types
          @post_types = @post_types.paginate(page: params[:page], per_page: current_site.admin_per_page)
          render 'index'
        end

        def show; end

        def edit
          add_breadcrumb I18n.t('camaleon_cms.admin.button.edit')
        end

        def update
          if @post_type.update(@data_term)
            @post_type.set_field_values(cama_permitted_field_options('PostType')) if params[:field_options].present?
            hooks_run('updated_post_type', { post_type: @post_type })
            flash[:notice] = t('camaleon_cms.admin.post_type.message.updated')
            redirect_to action: :index
          else
            edit
          end
        end

        def create
          @post_type = current_site.post_types.new(@data_term)
          if @post_type.save
            @post_type.set_field_values(cama_permitted_field_options('PostType')) if params[:field_options].present?
            hooks_run('created_post_type', { post_type: @post_type })
            flash[:notice] = t('camaleon_cms.admin.post_type.message.created')
            redirect_to action: :index
          else
            index
          end
        end

        def destroy
          flash[:notice] = t('camaleon_cms.admin.post_type.message.deleted') if @post_type.destroy
          redirect_to action: :index
        end

        private

        def set_data_term
          # parent_id is the post type's site_id (alias_attribute). It is set from the site association
          # on create and must never be reassigned, so it is not accepted from the request; otherwise a
          # settings manager could re-home the post type onto another site (audit finding H8).
          data_term = params.require(:post_type).permit(:name, :slug, :description)
          data_term[:data_options] = params[:meta].present? ? post_type_meta_params : {}
          @data_term = data_term
        end

        def post_type_meta_params
          params.require(:meta).permit(:icon, :has_layout, :default_layout, :has_template, :default_template,
                                       :has_category, :has_single_category, :has_tags, :has_content, :has_summary,
                                       :has_comments, :has_featured, :has_seo, :has_parent_structure, :has_picture,
                                       :posts_image_dimension, :posts_thumb_versions, :posts_thumb_size,
                                       :is_required_picture, :contents_route_format, :default_thumb)
        end

        def set_post_type
          @post_type = current_site.post_types.find_by(id: params[:id])
        rescue StandardError
          flash[:error] = t('camaleon_cms.admin.post_type.message.error')
          redirect_to cama_admin_path
        end
      end
    end
  end
end
