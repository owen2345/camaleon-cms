module CamaleonCms
  module Admin
    module Posts
      class DraftsController < CamaleonCms::Admin::PostsController
        before_action :set_post_data_params, only: %i[create update]

        def index
          render json: @post_type
        end

        def create
          if @draft_parent_post.present?
            # A draft buffer is an artifact of editing its parent post — authorize that post,
            # and only ever touch the current user's own buffer
            authorize! :update, @draft_parent_post
            @post_draft = @post_type.posts.drafts.where(post_parent: @draft_parent_post.id,
                                                        user_id: cama_current_user.id).first
            if @post_draft.present?
              @post_draft.set_option('draft_status', @post_draft.status)
              @post_draft.attributes = @post_data
            end
          else
            authorize! :create_post, @post_type
          end
          if @post_draft.blank?
            @post_draft = @post_type.posts.new(@post_data)
            @post_draft.user_id = cama_current_user.id
          end
          r = { post: @post_draft, post_type: @post_type }
          hooks_run('create_post_draft', r)
          if @post_draft.save(validate: false)
            @post_draft.set_params(params[:meta], params[:field_options], @post_data[:keywords])
            msg = { draft: { id: @post_draft.id },
                    _drafts_path: cama_admin_post_type_draft_path(@post_type.id, @post_draft) }
            r = { post: @post_draft, post_type: @post_type }
            hooks_run('created_post_draft', r)
          else
            msg = { error: @post_draft.errors.full_messages }
          end

          render json: msg
        end

        def update
          @post_draft = @post_type.posts.drafts.where(user_id: cama_current_user.id).find(params[:id])
          authorize! :update, @post_draft.parent || @post_draft
          @post_draft.attributes = @post_data
          r = { post: @post_draft, post_type: @post_type }
          hooks_run('update_post_draft', r)
          if @post_draft.save(validate: false)
            @post_draft.set_params(params[:meta], params[:field_options], params[:options])
            hooks_run('updated_post_draft', { post: @post_draft, post_type: @post_type })
            msg = { draft: { id: @post_draft.id } }
          else
            msg = { error: @post_draft.errors.full_messages }
          end
          render json: msg
        rescue ActiveRecord::RecordNotFound
          # Another user's buffer answers exactly like a nonexistent draft id (same rescue
          # behavior as PostsController#set_post) — no existence oracle for foreign buffers
          flash[:error] = t('camaleon_cms.admin.post.message.error', post_type: @post_type.decorate.the_title)
          redirect_to cama_admin_path
        end

        def destroy; end

        private

        def set_post_data_params
          post_data = params
                      .require(:post).permit(
                        :title, :slug, :content, :excerpt, :status, :comment_status, :visibility,
                        :visibility_value, :post_order, :published_at
                      ).to_h
          post_data.delete(:created_at) if params[:post][:created_at].blank?
          post_data.delete(:updated_at) if params[:post][:updated_at].blank?
          post_data[:status] = 'draft_child'
          if action_name == 'create'
            @draft_parent_post = current_site.posts.find_by(id: params[:post_id]) if params[:post_id].present?
            # post_parent is create-only and always overwritten — never client-writable via post[post_parent]
            post_data[:post_parent] = @draft_parent_post&.id
          end
          post_data[:data_tags] = params[:tags].to_s
          post_data[:data_categories] = params[:categories] || []
          @post_data = post_data
        end
      end
    end
  end
end
