module CamaleonCms
  module SiteHelper
    # return current site or assign a site as a current site
    def current_site(site = nil)
      if site.present?
        CurrentRequest.site = site.decorate
        CurrentRequest.frontend_current_theme = nil
        return CurrentRequest.site
      end

      # Honor a caller-set @current_site (HtmlMailer and other background senders assign it) before the
      # memoized CurrentRequest.site, so a delivery for another site resolves against that site rather
      # than the request's. Restores 2.9.2; without it, multisite/background mail resolves the wrong site
      # or raises NameError on `request` in a job. See regression audit M21. Read via
      # instance_variable_get to match #current_theme and avoid Rails/HelperInstanceVariable.
      caller_site = (instance_variable_get(:@current_site) if instance_variable_defined?(:@current_site))
      if caller_site.present?
        CurrentRequest.site = caller_site
        return caller_site
      end

      return CurrentRequest.site if CurrentRequest.site.present?

      if PluginRoutes.get_sites.size == 1
        site = begin
          CamaleonCms::Site.first.decorate
        rescue StandardError
          nil
        end
      else
        host = [request.original_url.to_s.parse_domain]
        host << request.subdomain if request.subdomain.present?
        site = begin
          CamaleonCms::Site.where(slug: host).first.decorate
        rescue StandardError
          nil
        end
      end
      r = { site: site, request: begin
        request
      rescue StandardError
        nil
      end }
      begin
        cama_current_site_helper(r)
      rescue StandardError
        nil
      end
      if r[:site].blank?
        Rails.logger.error(
          'Camaleon CMS - No site matches this request: map your domains to your sites ' \
            '(https://camaleon.website/documentation/category/139779-examples/how.html), ' \
            'or pass the site with current_site(site) outside a request'
            .cama_log_style(:red)
        )
      end
      CurrentRequest.site = r[:site]
      CurrentRequest.frontend_current_theme = nil
      CurrentRequest.site
    end

    # return current theme model for current site
    def current_theme
      preview_theme = (instance_variable_get(:@_current_theme) if instance_variable_defined?(:@_current_theme))
      return CurrentRequest.frontend_current_theme = preview_theme if preview_theme.present?

      theme = CurrentRequest.frontend_current_theme
      return theme if theme.present?

      theme = current_site.get_theme.decorate
      CurrentRequest.frontend_current_theme = theme
    end

    # get list templates files of current theme
    def cama_get_list_template_files(post_type)
      contained_files = []
      Dir[File.join(current_theme.settings['path'], 'views', '*')].each do |path|
        f_name = File.basename(path)
        contained_files << f_name.split('.').first if f_name.include?('template_')
      end
      _args = { tempates: contained_files, post_type: post_type }
      hooks_run('post_get_list_templates', _args)
      _args[:tempates]
    end

    # get list layouts files of current theme
    # return an array of layouts for current theme
    def cama_get_list_layouts_files(post_type)
      contained_files = []
      Dir[File.join(current_theme.settings['path'], 'views', 'layouts', '*')].each do |path|
        f_name = File.basename(path)
        contained_files << f_name.split('.').first unless f_name.start_with?('_')
      end
      _args = { layouts: contained_files, post_type: post_type }
      hooks_run('post_get_list_layouts', _args)
      _args[:layouts]
    end

    # get locale language
    def current_locale
      I18n.locale.to_s
    end

    # ***************** administration HELPERS ***********************
    # do common actions after site installation
    # theme_key: theme slug of the theme for site
    def site_after_install(site, theme_key = nil)
      theme_key ||= site.get_theme_slug
      cama_require_theme(theme_key)
      _s = current_site
      # A theme preview is a theme of the site of the request, so the hooks of the new site do not go to it.
      cama_without_preview_theme do
        current_site(site)
        # The site gets its theme before the plugins, so the hooks of the plugin installs go to that theme.
        current_site.set_option('_theme', theme_key)
        # The plugins and the theme share one draw of the routes, when the routes already have them.
        PluginRoutes.reload_once do
          PluginRoutes.system_info['default_plugins'].each { |p| plugin_install(p) } # auto install plugins
          # A new site has no theme to uninstall, so no on_inactive hook runs.
          cama_activate_theme(theme_key)
        end
      ensure
        # A handler that raises does not leave the new site as the current site of the request.
        current_site(_s) if _s.present?
      end
    end

    # Installs the theme with the key for the current site. The switch is all or nothing: when a step
    # raises, for example the on_active hook of the new theme, the error goes to the caller. The site
    # then keeps its old theme, and no row that the switch wrote stays. PluginRoutes drops the data of
    # the switch after the rollback, and the request gets its old current theme back. A hook that raises
    # ActiveRecord::Rollback outside a transaction block of its own also rolls the switch back. The caller
    # then gets ActiveRecord::ActiveRecordError.
    #
    # A change that a hook makes outside the database, such as a file or a mail, does not roll back. On
    # MySQL, a DDL statement in a hook commits the transaction, so the rows of the switch stay too. A
    # commit callback can raise after the commit. The switch then stays: the request keeps the new theme,
    # and the helper draws the routes before it gives the error.
    #
    # Intended limits:
    # - While the connection pool has a transaction isolation level (Rails 8.1), Rails permits no
    #   savepoint. A switch in a transaction of the caller then raises
    #   ActiveRecord::TransactionIsolationError before its first write.
    # - The transaction is on the connection pool of ActiveRecord::Base. It does not cover a host that
    #   puts the Camaleon models on another pool.
    # - A hook can create a record through another association of a record in memory, such as
    #   current_site.post_types. After the rollback, that record stays there with no row in the database.
    # - The error of the draw after the savepoint says that in_transaction? is false. A caller that lets
    #   this error through a transaction of its own rolls the switch back, and the error does not say so.
    def site_install_theme(key)
      cama_require_theme(key)
      # A hook can draw the routes in the transaction of the switch, and that draw waits for the other
      # requests. A request that runs then can wait for a lock of that transaction, so the two wait for
      # each other. So the switch takes the lock of the route reload first. It waits until the requests
      # that run are done, for RouteReloadLock::WAIT_TIMEOUT seconds at most. A new request waits until
      # the switch is done.
      #
      # Another thread can hold the lock, for example a second switch. The switch never runs with no
      # lock: it waits for that thread for RouteReloadLock::HOLDER_WAIT_TIMEOUT seconds at most. Then it
      # raises RouteReloadLock::WaitTimeout before its first write.
      CamaleonCms::RouteReloadLock.exclusive(wait_for_holder: true) { cama_switch_theme(key) }
    end

    # uninstall current theme form current site
    def site_uninstall_theme
      key = current_site.get_theme_slug
      theme = PluginRoutes.theme_info(key)
      # Site#get_theme creates a missing record, so the record is always there.
      theme_model = current_site.get_theme(key)
      cama_with_current_theme(theme_model) { hook_run(theme, 'on_inactive', theme_model) }
      # theme_model.destroy
    end

    # add host and port to args of the current site visited
    # (only if the request is coming from console or tasks i.e. not web browser)
    # args: Hash
    # sample: {} will return {host: 'localhost', port: 3000}
    def cama_current_site_host_port(args)
      args[:host], args[:port] = current_site.try(:get_domain).to_s.split(':') if cama_is_test_request?
      args
    end

    # check if the request created by draper or request is not defined
    def cama_is_test_request?
      (request && defined?(ActionController::TestRequest) && request.is_a?(ActionController::TestRequest)) || !request
    end

    private

    # Raises ArgumentError when no installed theme has the key. An install calls it before its first
    # write, so an unknown key leaves the site as it was.
    def cama_require_theme(key)
      return if PluginRoutes.theme_info(key).present?

      raise ArgumentError, "Camaleon CMS - Theme not installed: #{key.inspect}"
    end

    # Runs the switch of site_install_theme, which holds the lock of the route reload.
    def cama_switch_theme(key)
      cama_forget_site_reads
      old_theme = CurrentRequest.frontend_current_theme
      switch = nil
      trial = nil
      switched = false
      begin
        # A savepoint, so a rollback undoes only the switch, also in a transaction of the caller. Rails 7.1
        # and later open no savepoint in such a transaction that ran no statement, so the helper forces one.
        CamaleonCms::CallerTransaction.require_savepoint!
        CamaleonCms::CallerTransaction.force_savepoint
        ActiveRecord::Base.transaction(requires_new: true) do
          # ActiveRecord::Base.connection leases a connection for good, which a host can refuse (Rails 7.2+).
          switch = ActiveRecord::Base.connection_pool.active_connection?&.current_transaction
          site_uninstall_theme
          cama_activate_theme(key, reload: false)
          cama_check_switch_transaction
          # A route file that raises fails the trial here, so the switch rolls back. A trial takes no lock.
          trial = PluginRoutes.trial_routes
          cama_check_switch_transaction
        end
        # Rails takes an ActiveRecord::Rollback, and the transaction raises no error. A hook can raise it,
        # and a before_commit callback can raise it at the commit. The state of the transaction shows both.
        unless switch&.state&.committed?
          raise ActiveRecord::ActiveRecordError,
                "Camaleon CMS - ActiveRecord::Rollback rolled back the switch to the theme #{key.inspect}"
        end
        switched = true
      ensure
        cama_end_failed_switch(old_theme, switch, trial) unless switched
      end
      cama_draw_switch_routes(trial)
    end

    # Another theme switch can end between the first read of the caller and the lock. The site object
    # then holds the options of that time, and the query cache of a request holds the theme row of that
    # time. The switch drops both, so it reads the theme that the other switch stored. The current
    # theme of the request stays, and a failed switch gives it back.
    #
    # A site can also hold its metas in memory, for example a site of PluginRoutes.get_sites. Its reads
    # come from those rows, so the switch loads them again. A load drops a meta or a change that the
    # caller did not save. So such metas stay as they are, and the switch then reads the old rows
    # (intended).
    def cama_forget_site_reads
      current_site.cama_clear_cache
      ActiveRecord::Base.clear_query_caches_for_current_thread
      metas = current_site.metas
      unsaved = metas.target.any? { |meta| meta.new_record? || meta.changed? }
      metas.reload if current_site.persisted? && metas.loaded? && !unsaved
    end

    # Draws the routes of the app after the savepoint, so only a switch that stays reaches this draw.
    # PluginRoutes.request_reload says when the draw uses the data of the trial. A trial of this draw
    # can fail, and the switch then stays. So the error says that no transaction rolls the change back
    # (in_transaction? is false), also in a transaction of the caller.
    def cama_draw_switch_routes(trial)
      PluginRoutes.request_reload(trial: trial)
    rescue CamaleonCms::RouteDrawError => e
      raise unless e.in_transaction?

      raise CamaleonCms::RouteDrawError.new(e.cause, in_transaction: false), cause: e.cause
    end

    # Ends a switch that raised an exception of any class, for example a timeout of the caller. Rails
    # rolled the switch back, so the request gets its old current theme back. The themes and the plugins
    # of the site hold the records that the switch created, and the database has no row for them. The
    # reset drops them, or the next save of the site can store them again. After the error of a commit
    # callback, the switch stays, so the helper draws its routes. The caller gets the error of the callback, so
    # an error of this draw goes to the log.
    def cama_end_failed_switch(old_theme, switch, trial)
      committed = switch&.state&.committed?
      unless committed
        CurrentRequest.frontend_current_theme = old_theme
        # A switch that failed before its transaction created no record. The caller can hold unsaved
        # records in these associations, and a reset drops them.
        [current_site.themes, current_site.plugins].each(&:reset) if switch
      end
      # PluginRoutes draws the routes again now, when a hook drew them from the rows of the switch.
      PluginRoutes.settle_route_data(quiet: true)
      PluginRoutes.request_reload(trial: trial) if committed
    rescue StandardError, ScriptError => e
      Rails.logger&.error("Camaleon CMS: the routes of the theme switch were not drawn (#{e.class}: #{e.message})")
    end

    # On PostgreSQL, a statement that fails stops the transaction, also when a hook or a read of the trial
    # rescues its error. The commit of a stopped transaction rolls back with no error. This read skips the
    # query cache, so it raises ActiveRecord::StatementInvalid in a stopped transaction, and the theme
    # switch rolls back. The switch reads before its trial too. With no such read, the trial runs in a
    # transaction that a hook stopped. A route file that reads the database then fails the trial, and the
    # error names the routes, not the cause.
    def cama_check_switch_transaction
      CamaleonCms::Site.uncached { CamaleonCms::Site.exists?(current_site.id) }
    end

    # Makes the theme the theme of the current site, and runs the on_active hook of the theme. With
    # reload: false, the caller reloads the routes.
    def cama_activate_theme(key, reload: true)
      current_site.set_option('_theme', key)
      theme = PluginRoutes.theme_info(key)
      current_site.themes.update_all(status: 'inactive') # rubocop:disable Rails/SkipsModelValidations
      theme_model = current_site.themes.where(slug: key).first_or_create! { |t| t.name = theme[:name] }
      attrs = { status: nil }
      # A read of current_theme before the install creates the record with its slug as its name.
      attrs[:name] = theme[:name] if theme_model.name.blank? || theme_model.name == key
      theme_model.update(attrs)
      cama_with_current_theme(theme_model) { hook_run(theme, 'on_active', theme_model) }
      PluginRoutes.request_reload if reload
    end

    # Runs the block with theme_model as the current theme of the request. The request read its
    # current theme before the install, so a hook that an on_active or on_inactive handler fires would
    # go to that theme, and the theme helpers would give its paths. The theme stays the current theme
    # after the block. A request with a theme preview (ccc_theme_preview) gets its preview theme back.
    def cama_with_current_theme(theme_model)
      cama_without_preview_theme do
        CurrentRequest.frontend_current_theme = theme_model.decorate
        yield
      end
    end

    # Runs the block with no theme preview. After the block, also when it raises, a request with a
    # theme preview (ccc_theme_preview) gets its preview theme back. This includes CurrentRequest, which
    # the view lookup reads directly.
    def cama_without_preview_theme
      preview_theme = (instance_variable_get(:@_current_theme) if instance_variable_defined?(:@_current_theme))
      instance_variable_set(:@_current_theme, nil) if preview_theme
      yield
    ensure
      if preview_theme
        instance_variable_set(:@_current_theme, preview_theme)
        CurrentRequest.frontend_current_theme = preview_theme
      end
    end
  end
end
