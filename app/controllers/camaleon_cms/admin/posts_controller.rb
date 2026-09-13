module CamaleonCms
  module Admin
    class PostsController < CamaleonCms::AdminController
      include CamaleonCms::Admin::CustomFieldsConcern
      include CamaleonCms::Admin::PostViewChoicesConcern

      # The template and layout fields a post save can carry, each with the helper that lists what the
      # post editor offers for it. A non-admin may submit only an offered value, or a blank one. Keys are
      # the canonical (folded) field names: a submitted key is folded the same way before it is matched,
      # so a case- or space-variant cannot slip a value past the check into the row the store resolves it
      # to.
      OFFERED_CHOICE_FIELDS = {
        meta: { 'template' => :cama_get_list_template_files, 'layout' => :cama_get_list_layouts_files },
        options: { 'default_template' => :cama_get_list_template_files,
                   'default_layout' => :cama_get_list_layouts_files }
      }.freeze

      # A meta or option key a save accepts is an ASCII word. The store resolves a key under the
      # database's collation, and MySQL's defaults fold more than case: accents on every default
      # collation (`témplate` = `template`) and compatibility variants on the UCA ones (`＿default` =
      # `_default`), while `utf8mb4_0900_ai_ci` is NO PAD (a trailing space is not ignored there). No
      # request-side folding reproduces that, and every field the editor and the surveyed plugins use is
      # an ASCII word, so any other key is refused instead of folded.
      FIELD_NAME_FORMAT = /\A[A-Za-z0-9_.-]+\z/

      add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.contents')

      before_action :set_post_type, except: [:ajax]
      before_action :set_post, only: %w[show edit update destroy]
      skip_before_action :admin_logged_actions, only: %i[trash restore destroy ajax], raise: false
      skip_before_action :verify_authenticity_token, only: [:ajax], raise: false

      def index
        authorize! :posts, @post_type
        # Array/hash-typed query params (?q[]=x, ?s[]=published, ?taxonomy_id[]=1) have no meaning here
        # and 500ed the action (Array#downcase / Array#to_sym / find(Array).decorate); treat them as absent.
        %i[q s taxonomy taxonomy_id].each { |k| params[k] = nil unless params[k].nil? || params[k].is_a?(String) }
        per_page = current_site.admin_per_page
        posts_all = @post_type.posts.eager_load(:parent, :post_type)
        if params[:taxonomy].present? && params[:taxonomy_id].present?
          # Security (audit 2026-08-11 M11): keep the listing scoped to @post_type. The taxonomy is
          # resolved within the authorized post type -- a foreign category/tag id raises RecordNotFound
          # instead of rendering that taxonomy's title/edit URL in the breadcrumb (a name/existence
          # oracle across the very boundary `authorize! :posts, @post_type` draws). The listing then
          # intersects with the post type's posts, so a filter can only ever narrow the authorized set.
          if params[:taxonomy] == 'category'
            cat_owner = @post_type.full_categories.find(params[:taxonomy_id]).decorate
            # reorder(nil): the relation becomes an IN subquery, where its default-scope ORDER BY is dead sort work
            posts_all = posts_all.where(id: cat_owner.posts.reorder(nil))
            add_breadcrumb t('camaleon_cms.admin.post_type.category'), @post_type.the_admin_url('category')
            add_breadcrumb cat_owner.the_title, cat_owner.the_edit_url
          end

          if params[:taxonomy] == 'post_tag'
            tag_owner = @post_type.post_tags.find(params[:taxonomy_id]).decorate
            posts_all = posts_all.where(id: tag_owner.posts.reorder(nil))
            add_breadcrumb t('camaleon_cms.admin.post_type.tags'), @post_type.the_admin_url('tag')
            add_breadcrumb tag_owner.the_title, tag_owner.the_edit_url
          end
        end

        if params[:q].present?
          params[:q] = (params[:q] || '').downcase
          posts_all = posts_all.where(
            "LOWER(#{CamaleonCms::Post.table_name}.title) LIKE ? OR LOWER(#{CamaleonCms::Post.table_name}.slug) LIKE ?",
            "%#{params[:q]}%",
            "%#{params[:q]}%"
          )
        end

        posts_all = cama_admin_visible_posts(posts_all, [@post_type])

        @posts = posts_all
        params[:s] = 'published' if params[:s].blank?
        @lists_tab = params[:s]
        case params[:s]
        when 'published', 'pending', 'trash'
          @posts = @posts.send(params[:s])
        when 'draft'
          @posts = @posts.drafts
        when 'all'
          @posts = @posts.no_trash
        end

        @btns = {
          published: "#{t('camaleon_cms.admin.post_type.published')} (#{posts_all.published.size})",
          all: "#{t('camaleon_cms.admin.post_type.all')} (#{posts_all.no_trash.size})",
          pending: "#{t('camaleon_cms.admin.post_type.pending')} (#{posts_all.pending.size})",
          draft: "#{t('camaleon_cms.admin.post_type.draft')} (#{posts_all.drafts.size})",
          trash: "#{t('camaleon_cms.admin.post_type.trash')} (#{posts_all.trash.size})"
        }
        per_page = 9_999_999 if @post_type.manage_hierarchy?
        r = { posts: @posts, post_type: @post_type, btns: @btns, all_posts: posts_all, render: 'index',
              per_page: per_page }
        hooks_run('list_post', r)
        add_breadcrumb(@btns[params[:s].to_sym].to_s) if params[:s].present?
        @posts = r[:posts].paginate(page: params[:page], per_page: r[:per_page])
        render r[:render]
      end

      def show; end

      def new
        add_breadcrumb I18n.t('camaleon_cms.admin.button.new')
        authorize! :create_post, @post_type
        @post_form_extra_settings = []
        @post ||= @post_type.posts.new
        r = { post: @post, post_type: @post_type, extra_settings: @post_form_extra_settings, render: 'form' }
        hooks_run('new_post', r)
        render r[:render]
      end

      def create
        authorize! :create_post, @post_type
        post_data = get_post_data(true)
        begin
          CamaleonCms::Post.drafts.find(post_data[:draft_id]).destroy
        rescue StandardError
          nil
        end
        @post = @post_type.posts.new(post_data)
        r = { post: @post, post_type: @post_type }
        hooks_run('create_post', r)
        @post = r[:post]
        if save_post_with_fields(@post)
          flash[:notice] = t('camaleon_cms.admin.post.message.created', post_type: @post_type.decorate.the_title)
          r = { post: @post, post_type: @post_type }
          hooks_run('created_post', r)
          redirect_to action: :edit, id: @post.id
        else
          # render 'form'
          new
        end
      end

      def edit
        add_breadcrumb I18n.t('camaleon_cms.admin.button.edit')
        authorize! :update, @post
        @post_form_extra_settings = []
        r = { post: @post, post_type: @post_type, extra_settings: @post_form_extra_settings, render: 'form' }
        hooks_run('edit_post', r)
        render r[:render]
      end

      def update
        post_data = get_post_data
        delete_drafts = false
        if @post.draft_child? && @post.parent.present?
          # This is a draft (as a child of the original post)
          original_parent = @post.parent.parent
          post_data[:post_parent] = original_parent&.id
          @post = @post.parent
          delete_drafts = true
        elsif @post.draft?
          # This is a normal draft (post whose status was set to 'draft'): publishing it on save is held
          # to the same publish rule as an explicit status.
          @post.status = publish_or_pending('published') if post_data[:status].blank?
        end
        authorize! :update, @post
        r = { post: @post, post_type: @post_type }
        hooks_run('update_post', r)
        @post = r[:post]
        if save_post_with_fields(@post, post_data)
          # delete drafts only on successful update operation
          @post.drafts.destroy_all if delete_drafts
          hooks_run('updated_post', { post: @post, post_type: @post_type })
          flash[:notice] = t('camaleon_cms.admin.post.message.updated', post_type: @post_type.decorate.the_title)
          redirect_to action: :edit, id: @post.id
        else
          edit
        end
      end

      def trash
        @post = @post_type.posts.find(params[:post_id])
        authorize! :destroy, @post
        @post.set_option('status_default', @post.status)
        # @post.children.destroy_all unless @post.draft? TODO: why delete children?
        @post.update_column(:status, 'trash') # rubocop:disable Rails/SkipsModelValidations
        @post.update_extra_data
        hooks_run('trashed_post', { post: @post, post_type: @post_type })
        flash[:notice] = t('camaleon_cms.admin.post.message.trash', post_type: @post_type.decorate.the_title)
        redirect_to action: :index, s: params[:s]
      end

      def restore
        @post = @post_type.posts.find(params[:post_id])
        authorize! :update, @post
        unless @post.trash?
          flash[:error] = cama_post_message('restore_not_in_trash', post_type: @post_type.decorate.the_title)
          return redirect_to action: :index, s: params[:s]
        end

        # A corrupt or legacy `_default` (not a Hash) makes options[...] raise; read the stored status
        # only when options is a hash, otherwise restore to the default status.
        stored_options = @post.options
        previous_status = stored_options.is_a?(Hash) ? stored_options[:status_default] : nil
        # rubocop:disable Rails/SkipsModelValidations
        @post.update_column(:status, restorable_status(previous_status))
        # rubocop:enable Rails/SkipsModelValidations
        @post.update_extra_data
        hooks_run('restored_post', { post: @post, post_type: @post_type })
        flash[:notice] = t('camaleon_cms.admin.post.message.restore', post_type: @post_type.decorate.the_title)
        redirect_to action: :index, s: params[:s]
      end

      def destroy
        authorize! :destroy, @post
        r = { post: @post, post_type: @post_type, flag: true }
        hooks_run('destroy_post', r)
        if r[:flag]
          if @post.destroy
            hooks_run('destroyed_post', { post: @post, post_type: @post_type })
            flash[:notice] = t('camaleon_cms.admin.post.message.deleted', post_type: @post_type.decorate.the_title)
            return redirect_to action: :index, s: params[:s]
          else
            flash[:error] = @post.errors.full_messages.join(', ')
          end
        end
        redirect_to(request.referer || url_for(action: :index, s: params[:s]))
      end

      # ajax options
      def ajax
        json = { error: 'Not Found' }
        case params[:method]
        when 'exist_slug'
          slug = current_site.get_valid_post_slug(params[:slug].to_s, params[:post_id])
          json = { slug: slug, index: 1 }
        end
        render json: json
      end

      private

      # Persist the post together with its metas, field values and options atomically (audit M10).
      # Before this, the parent was saved and its metas committed before set_field_values ran, so a
      # field value the scan-and-reject gate refused (CustomFieldsRelationship RecordInvalid) left a
      # half-applied post -- an orphan on create, skipped options, only a redirect explaining why.
      # Wrapping the whole sequence in one transaction rolls the parent save back with the refused
      # value, and the RecordInvalid propagates to AdminController's rescue_from (flash + redirect
      # back) with nothing persisted. Returns true on success, false on a parent validation failure.
      #
      # The request's metas and options are checked first (post_params_refusals): a refused save writes
      # nothing, and the form re-renders with the submitted values and the refusals as errors.
      def save_post_with_fields(post, update_attrs = nil)
        refusals = post_params_refusals
        if refusals.any?
          post.assign_attributes(update_attrs) if update_attrs
          refusals.each { |message| post.errors.add(:base, message) }
          return false
        end

        ActiveRecord::Base.transaction do
          saved = update_attrs ? post.update(update_attrs) : post.save
          raise ActiveRecord::Rollback unless saved

          post.set_metas(params[:meta])
          post.set_field_values(cama_permitted_field_options('PostType_Post'))
          post.set_options(params[:options])
          true
        end
      end

      # The refusals for the metas and options this request carries: a key the engine maintains, for
      # everyone, and for a non-admin a template or layout the post editor does not offer. Any other key
      # is stored as submitted -- plugins and themes add their own fields to the post editor.
      def post_params_refusals
        malformed = malformed_container_refusals
        return malformed if malformed.any?

        status_refusals + summary_refusals + %i[meta options].flat_map { |group| group_refusals(group) }
      end

      # `meta[summary]` is content: the default theme renders the excerpt through `raw`, and a theme
      # without its own list partial falls back to it. Post#reject_untrusted_dangerous_content gates only
      # the content column (a meta row never passes through a model validation), so the summary is held
      # to the same detector, allowlist and messages here, for a user without the unfiltered-content
      # permission. Refused, never rewritten; a permission holder's summary is stored as written.
      def summary_refusals
        meta = params[:meta]
        summary = meta[:summary] if cama_hash_param?(meta)
        return [] if summary.blank? || can?(:post_content_unfiltered_html, @post_type)

        if CamaleonCms::UnsafeMarkup.too_large?(summary)
          ["meta[summary] #{cama_post_message('content_too_large')}"]
        elsif CamaleonCms::UnsafeMarkup.unsafe_html?(summary, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                                                              attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES)
          ["meta[summary] #{cama_post_message('content_rejected')}"]
        else
          []
        end
      end

      # A submitted status is one the editor offers, exactly: `Published` or `published ` is refused,
      # not folded, because the column stores it verbatim and MySQL's case-insensitive collation would
      # list it among the published posts while every Ruby check calls it unpublished. A blank status
      # is not a submission (get_post_data decides what it means).
      def status_refusals
        post = params[:post]
        status = post[:status] if cama_hash_param?(post)
        return [] if status.blank? || CamaleonCms::Post::EDITOR_STATUSES.include?(status)

        [cama_post_message('status_not_offered', field: 'post[status]')]
      end

      # `set_metas`/`set_options` iterate whatever `meta`/`options` is with `|key, value|`, so an array
      # of pairs (`meta[]=x`, or a JSON body `{"meta":[["template","..."]]}`) would be written key by
      # key while answering neither `keys` nor `key?` -- slipping past the checks below, and an array
      # `options` reaches `set_options`' `to_sym` and 500s. Refuse a present-but-not-hash container up
      # front, so nothing is read from it or written.
      def malformed_container_refusals
        %i[meta options].filter_map do |group|
          submitted = params[group]
          next if submitted.nil? || cama_hash_param?(submitted)

          cama_post_message('malformed_group', group: group.to_s)
        end
      end

      # One pass over a group's submitted pairs. Each key is folded the way the store resolves it, then
      # refused as not a field name or as engine-maintained (for everyone) or, for a non-admin, as a
      # template or layout the editor does not offer. A key gets at most one refusal.
      def group_refusals(group)
        listers = OFFERED_CHOICE_FIELDS[group]
        submitted_group_pairs(group).filter_map do |key, value|
          canonical = canonical_key(key)
          field = "#{group}[#{key}]"
          if !canonical.match?(FIELD_NAME_FORMAT)
            cama_post_message('key_not_a_field_name', key: field)
          elsif reserved_key?(group, canonical)
            cama_post_message('reserved_key', key: field)
          elsif !cama_current_user.admin? && (lister = listers[canonical]) &&
                !cama_offered_view_choice?(value, lister, @post_type)
            cama_post_message('value_not_offered', field: field)
          end
        end
      end

      def reserved_key?(group, canonical)
        case group
        when :meta then canonical.start_with?('_') || CamaleonCms::Post::ENGINE_META_KEYS.include?(canonical)
        when :options then CamaleonCms::Post::ENGINE_OPTION_KEYS.include?(canonical)
        else false
        end
      end

      # The submitted key/value pairs of a `meta`/`options` group (String keys), or {} when it is absent.
      # A present non-hash container was refused before this runs.
      def submitted_group_pairs(group)
        submitted = params[group]
        submitted.is_a?(ActionController::Parameters) ? submitted.to_unsafe_h : {}
      end

      # Fold a submitted key the way the metas store resolves an ASCII one. `set_meta`/`get_meta` look a
      # row up with `where(key:)`, which on MySQL's default collations matches case variants (and, on the
      # PAD SPACE ones, trailing-space variants), so `meta[Template]` would update the `template` row;
      # match it against the same field either way. Wider folding is refused up front (FIELD_NAME_FORMAT).
      def canonical_key(key)
        key.to_s.strip.downcase
      end

      # The status a trashed post returns to: the one it had when that is a status a post may be restored
      # to and the acting user may set it, otherwise pending.
      def restorable_status(previous)
        status = CamaleonCms::Post::RESTORABLE_STATUSES.include?(previous.to_s) ? previous.to_s : 'pending'
        publish_or_pending(status)
      end

      # Downgrade a would-be `published` status to `pending` for a user who cannot publish this post
      # type, leaving every other status untouched. The single source of the publish rule for the create,
      # update and restore paths, so a non-publisher cannot reach `published` through any of them.
      def publish_or_pending(status)
        status.to_s == 'published' && cannot?(:publish_post, @post_type) ? 'pending' : status
      end

      def cama_post_message(key, **vars)
        cama_t("camaleon_cms.admin.post.message.#{key}", vars)
      end

      # define post type parent
      def set_post_type
        @post_type = current_site.post_types.find_by(id: params[:post_type_id])
        if @post_type.blank?
          flash[:error] = t('camaleon_cms.admin.request_error_message')
          redirect_to cama_admin_path
          return
        end
        @post_type = @post_type.decorate
        add_breadcrumb @post_type.the_title, @post_type.the_admin_url
      end

      def set_post
        @post = @post_type.posts.find(params[:id])
        @post_decorate = @post.decorate
      rescue StandardError
        flash[:error] = t('camaleon_cms.admin.post.message.error', post_type: @post_type.decorate.the_title)
        redirect_to cama_admin_path
      end

      # return common params data for posts
      # is_create: indicate if this info is for create a new post
      def get_post_data(is_create = false)
        post_data = params
                    .require(:post).permit(
                      :title, :slug, :content, :excerpt, :status, :comment_status, :post_parent, :visibility,
                      :visibility_value, :post_order, :published_at
                    ).to_h
        post_data[:user_id] = cama_current_user.id if is_create
        # A blank status (absent, or an empty select value) means "leave the current status" on update, so
        # it is dropped before the write rather than written as ''; on create it takes the column default
        # ('published'), made explicit so the publish rule runs on it. A present status was already held
        # to the editor's set by status_refusals.
        post_data.delete(:status) if !is_create && post_data[:status].blank?
        post_data[:status] = 'published' if is_create && post_data[:status].blank?
        post_data[:status] = publish_or_pending(post_data[:status]) if post_data.key?(:status)
        post_data[:data_tags] = params[:tags].to_s
        post_data[:data_categories] = params[:categories] || []
        post_data
      end
    end
  end
end
