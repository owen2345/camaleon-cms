module CamaleonCms
  module Admin
    module Posts
      class DraftsController < CamaleonCms::Admin::PostsController
        before_action :set_post_data_params, only: %i[create update]

        def index
          # Security (audit 2026-08-11 M12): this action had no authorization, so any signed-in user
          # could read a post type's JSON. Gate it on the same permission the post listing requires.
          authorize! :posts, @post_type
          render json: @post_type
        end

        def create
          # A draft buffer is an artifact of editing its parent post — authorize that post,
          # and only ever touch the current user's own buffer.
          if @draft_parent_post.present?
            authorize! :update, @draft_parent_post
          else
            authorize! :create_post, @post_type
          end

          # A draft save is held to the same meta and option rules as the post save (see PostsController),
          # before anything is written. The save below also stores draft_status on a buffer that it finds.
          refusals = post_params_refusals
          return render(json: { error: refusals }) if refusals.any?

          if @draft_parent_post.present?
            @post_draft = @post_type.posts.drafts.where(post_parent: @draft_parent_post.id,
                                                        user_id: cama_current_user.id).first
          end
          if @post_draft
            draft_status = @post_draft.status
            @post_draft.attributes = @post_data
          else
            @post_draft = @post_type.posts.new(@post_data)
            @post_draft.user_id = cama_current_user.id
          end

          r = { post: @post_draft, post_type: @post_type }
          hooks_run('create_post_draft', r)
          if save_draft_with_fields(@post_draft, draft_status: draft_status)
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
          refusals = post_params_refusals
          return render(json: { error: refusals }) if refusals.any?

          @post_draft.attributes = @post_data
          r = { post: @post_draft, post_type: @post_type }
          hooks_run('update_post_draft', r)
          if save_draft_with_fields(@post_draft)
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

        # Stores the draft with its metas, field values and options in one transaction, as
        # PostsController#save_post_with_fields stores a post. Before, the draft save stored the draft row,
        # its metas, its categories and its tags before the custom-field values. A refused value then left
        # a new draft row. The post editor got no id of that row, so each later save of that editor
        # created one more row. Now a refusal rolls the whole draft save back, and it reaches the
        # rescue_from of AdminController.
        #
        # `draft_status` is the stored status of a buffer that #create found. The buffer keeps that
        # status as an option.
        #
        # Security: PostsController#save_post_params confines the field values to the slugs that the
        # post type registers. Raw params[:field_options] let a caller write custom_field_values with
        # slugs, ids and group numbers of its choice. The options come from params[:options], which
        # post_params_refusals checks.
        #
        # Returns true on success, and nil when a callback of the draft stops the save.
        def save_draft_with_fields(draft, draft_status: nil)
          ActiveRecord::Base.transaction do
            draft.set_option('draft_status', draft_status) if draft_status
            raise ActiveRecord::Rollback unless draft.save(validate: false)

            save_post_params(draft)
            true
          end
        end

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
