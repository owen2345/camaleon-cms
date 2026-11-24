# frozen_string_literal: true

# A theme switch uninstalls the old theme, stores the key of the new theme and runs the on_active hook
# of the new theme. When that hook raised, the site kept the new key and the rows that the hooks
# wrote. The new theme then stayed half-installed, and the front page could fail.
RSpec.describe 'A theme switch whose on_active hook raises', type: :request do
  include_context 'with theme hook probes'
  init_site

  let(:select_eval_error) { 'Not authorized to create select_eval fields' }
  let(:rollback_error) { 'Camaleon CMS - ActiveRecord::Rollback rolled back the switch to the theme "new"' }
  let(:stopped_transactions) { [] }
  let(:hook_error) { ArgumentError }
  let(:switch_transactions) { [] }

  def theme_state
    site = CamaleonCms::Site.find(@site.id)
    [site.get_theme_slug, site.themes.order(:id).pluck(:slug, :status)]
  end

  def plugin_state
    CamaleonCms::Site.find(@site.id).plugins.order(:id).pluck(:slug, :status)
  end

  def group_count
    CamaleonCms::CustomFieldGroup.where(slug: 'probe_new_fields').count
  end

  # The on_inactive handler of the old theme destroys its record, as the bundled theme "new" does. The
  # on_active handler of the new theme installs a plugin and adds a field group with a text field. Then
  # it adds a select_eval field, which Camaleon refuses for a role without the select_eval permission.
  def probe_helper
    log = hook_log
    stopped = stopped_transactions
    switches = switch_transactions
    error = hook_error
    Module.new do
      define_method(:probe_old_on_inactive) { |theme| theme.destroy }
      define_method(:probe_new_on_active) do |theme|
        plugin_install('visibility_post')
        group = theme.add_custom_field_group({ name: 'Probe fields', slug: 'probe_new_fields' })
        group.add_manual_field({ 'name' => 'Title', 'slug' => 'probe_title' }, { field_key: 'text_box' })
        group.add_manual_field({ 'name' => 'Code', 'slug' => 'probe_code' }, { field_key: 'select_eval' })
      end
      # The plugin install draws the routes of the app from the rows of the switch. Then the hook raises.
      define_method(:probe_install_and_raise_on_active) do |_theme|
        plugin_install('visibility_post')
        raise error, 'the hook raised'
      end
      # A hook can raise ActiveRecord::Rollback outside a transaction block of its own. The savepoint of the
      # switch takes that error and raises no error itself.
      define_method(:probe_rollback_on_active) do |theme|
        theme.add_custom_field_group({ name: 'Probe fields', slug: 'probe_new_fields' })
        raise ActiveRecord::Rollback
      end
      # The hook rescued the error of a statement, and the database stopped the transaction of the switch.
      define_method(:probe_stopped_on_active) do |_theme|
        stopped << ActiveRecord::Base.connection.current_transaction
      end
      # The hook notes the transaction of the switch, and writes nothing.
      define_method(:probe_noted_on_active) do |_theme|
        switches << ActiveRecord::Base.connection.current_transaction
      end
      # The post type settles the routes after the commit of the switch.
      define_method(:probe_post_type_on_active) do |_theme|
        current_site.post_types.create!(name: 'Probe books', slug: 'probe_books')
      end
      # A new slug of a post type asks for a reload of the routes after the commit of the switch.
      define_method(:probe_rename_post_type_on_active) do |_theme|
        current_site.post_types.find_by!(slug: 'post').update!(slug: 'probe_posts')
      end
      # A hook that calls itself with no end raises SystemStackError, which is no StandardError.
      define_method(:probe_stack_error_on_active) do |_theme|
        raise SystemStackError, 'stack level too deep'
      end
      # NotImplementedError is a ScriptError, which is no StandardError.
      define_method(:probe_script_error_on_active) do |_theme|
        raise NotImplementedError, 'not implemented'
      end
      # A request of the front page writes a row in a transaction of its own and then switches the theme.
      # The request rescues the error of the hook in that transaction.
      define_method(:probe_switch_in_transaction) do
        ActiveRecord::Base.transaction do
          current_site.set_meta('probe_caller', 'kept')
          begin
            site_install_theme('new')
          rescue CanCan::AccessDenied => e
            log << [:install_error, e.message]
          end
        end
      end
      # A request of the front page that switches the theme and rescues the error of the hook.
      define_method(:probe_switch_and_rescue) do
        site_install_theme('new')
      rescue CanCan::AccessDenied, ActiveRecord::ActiveRecordError, SystemStackError, NotImplementedError => e
        log << [:install_error, e.message, current_theme.slug, current_site.get_theme_slug]
      end
    end
  end

  def probe_hooks(front_switch: nil, on_active: 'probe_new_on_active', front_hook: 'front_before_load')
    hooks = { 'default' => { 'on_inactive' => ['probe_old_on_inactive'] },
              'new' => { 'on_active' => [on_active] } }
    hooks['default'][front_hook] = [front_switch] if front_switch
    probe_theme_hooks(probe_helper, hooks)
  end

  describe 'a switch in the admin panel by a role without the select_eval permission' do
    let(:theme_manager) do
      role = @site.user_roles.create!(name: 'Theme manager', slug: 'theme_manager')
      role.set_meta("_manager_#{@site.id}", { 'themes' => 1 })
      create(:user, role: role.slug, site: @site)
    end

    before do
      probe_hooks
      sign_in_as(theme_manager, site: @site)
    end

    it 'keeps the old theme and stores no row of the switch' do
      state_before = theme_state
      plugins_before = plugin_state

      get cama_admin_appearances_themes_path, params: { set: 'new' }

      expect(response).to redirect_to(cama_admin_dashboard_path)
      expect(flash[:error]).to eq("Error: #{select_eval_error}")
      expect(theme_state).to eq(state_before)
      expect(plugin_state).to eq(plugins_before)
      enabled_plugins = PluginRoutes.enabled_plugins(CamaleonCms::Site.find(@site.id)).pluck('key')
      expect(enabled_plugins).not_to include('visibility_post')
      expect(group_count).to eq(0)
    end

    it 'keeps the front page of the old theme' do
      get cama_admin_appearances_themes_path, params: { set: 'new' }
      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('themes/default/')
      expect(response.body).not_to include('themes/new/')
    end
  end

  # No request of Camaleon rescues the error of a switch and then renders a page. So a handler of the
  # front page does it. The request has no user, so Camaleon refuses the select_eval field.
  describe 'a switch in a request that rescues the error' do
    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue')
      # init_site read the hooks of the old theme before the stub, and PluginRoutes keeps them. A
      # reload clears that data.
      PluginRoutes.reload
    end

    it 'keeps the old theme as the current theme of the request' do
      state_before = theme_state

      get '/'

      expect(hook_log).to eq([[:install_error, select_eval_error, 'default', 'default']])
      expect(theme_state).to eq(state_before)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('themes/default/')
    end
  end

  # The switch runs in a savepoint. Without the savepoint, the switch joins the transaction of the caller.
  # A caller that rescues the error in that transaction then stores every row of the switch.
  describe 'a switch in a transaction of the caller' do
    before do
      probe_hooks(front_switch: 'probe_switch_in_transaction')
      PluginRoutes.reload
    end

    it 'rolls back only the switch, and keeps the row of the caller' do
      state_before = theme_state

      get '/'

      expect(hook_log).to eq([[:install_error, select_eval_error]])
      expect(theme_state).to eq(state_before)
      expect(group_count).to eq(0)
      expect(CamaleonCms::Site.find(@site.id).get_meta('probe_caller')).to eq('kept')
      expect(response.body).to include('themes/default/')
    end
  end

  # In a transaction of the caller that ran no statement, Rails 7.1 and later open no savepoint: a failed
  # switch restarts that transaction. So the helper marks that transaction as dirty first
  # (CamaleonCms::CallerTransaction). In each kind of transaction of the caller below, a failed switch
  # rolls back to its own savepoint.
  describe 'the rollback to the savepoint of the switch' do
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_rollback_on_active')
      CurrentRequest.site = @site
    end

    # Runs a switch that fails in a transaction of the caller of the given kind. Returns the SAVEPOINT
    # and ROLLBACK TO SAVEPOINT statements of the switch, and the SAVEPOINT statement of its own
    # savepoint. Rails names a savepoint after the number of open transactions before it.
    def statements_of_a_failed_switch(kind)
      ActiveRecord::Base.transaction(joinable: kind != :not_joinable) do
        CamaleonCms::Site.where(id: @site.id).exists? if kind == :used
        depth = ActiveRecord::Base.connection_pool.with_connection(&:open_transactions)
        statements = sql_queries(matching: /\A(ROLLBACK TO )?SAVEPOINT/, include_transactions: true) do
          helper_object.site_install_theme('new')
        rescue ActiveRecord::ActiveRecordError
          nil
        end
        [statements, "SAVEPOINT active_record_#{depth}"]
      end
    end

    {
      new: 'when no statement ran in the transaction of the caller',
      used: 'when a statement ran in the transaction of the caller',
      not_joinable: 'when the transaction of the caller is not joinable'
    }.each do |kind, description|
      it "rolls a failed switch back to its own savepoint #{description}" do
        state_before = theme_state

        statements, savepoint = statements_of_a_failed_switch(kind)

        expect(statements).to include(savepoint)
        expect(statements.last).to eq("ROLLBACK TO #{savepoint}")
        expect(theme_state).to eq(state_before)
      end
    end

    # The caller sets an isolation level in its open transaction, so the pool has no such level. Rails
    # 8.1 then refuses each new transaction, also the transaction of the switch. The guard of the helper
    # is not in this flow, and the error is the error of Rails. The next example covers the guard.
    it 'gets the error of Rails when the caller sets an isolation level in its open transaction' do
      skip 'This Rails has no pool isolation level' unless ActiveRecord.respond_to?(:with_transaction_isolation_level)
      state_before = theme_state

      expect do
        ActiveRecord::Base.transaction do
          ActiveRecord.with_transaction_isolation_level(:read_committed) { helper_object.site_install_theme('new') }
        end
      end.to raise_error(ActiveRecord::TransactionIsolationError) { |error|
        expect(error.message).not_to include('Camaleon CMS')
      }
      expect(theme_state).to eq(state_before)
    end

    # Rails 8.1 permits no savepoint while the connection pool has a transaction isolation level. With
    # no savepoint, a caller that rescues the error stores a half switch, so the switch refuses (intended).
    # Rails raises the same error for the savepoint. But Rails then drops the connection of the caller,
    # and the transaction of the caller goes with it. The example stubs the level of the pool (intended):
    # the real API raises an error inside the transaction of an example.
    it 'keeps the connection of the caller while the pool has an isolation level at the savepoint' do
      pool = ActiveRecord::Base.connection_pool
      skip 'This Rails has no pool isolation level' unless pool.respond_to?(:pool_transaction_isolation_level)
      expect(ActiveRecord::Base.connection).not_to receive(:throw_away!)
      state_before = theme_state

      expect do
        ActiveRecord::Base.transaction do
          allow(pool).to receive(:pool_transaction_isolation_level).and_return(:read_committed)
          helper_object.site_install_theme('new')
        ensure
          allow(pool).to receive(:pool_transaction_isolation_level).and_call_original
        end
      end.to raise_error(ActiveRecord::TransactionIsolationError, /Camaleon CMS/)
      expect(theme_state).to eq(state_before)
    end
  end

  # A switch that fails before its transaction created no record. The reset of the themes and the plugins
  # of the site then dropped only the unsaved records of the caller.
  describe 'a switch that fails before its transaction' do
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_noted_on_active')
      CurrentRequest.site = @site
      allow(CamaleonCms::CallerTransaction).to receive(:force_savepoint)
        .and_raise(ActiveRecord::ConnectionNotEstablished, 'no connection')
    end

    it 'keeps the unsaved records of the caller in the themes and the plugins of the site' do
      theme = @site.themes.build(slug: 'probe_unsaved')
      plugin = @site.plugins.build(slug: 'probe_unsaved')

      expect { helper_object.site_install_theme('new') }.to raise_error(ActiveRecord::ConnectionNotEstablished)

      expect(@site.themes.target).to include(theme)
      expect(@site.plugins.target).to include(plugin)
      expect(switch_transactions).to be_empty
    end
  end

  # A plugin install in a hook draws the routes of the app from the rows of the switch. After the rollback,
  # the helper draws them again from the stored rows, before the caller gets the error.
  describe 'a failed switch whose hook drew the routes' do
    let(:draws) { [] }
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_install_and_raise_on_active')
      CurrentRequest.site = @site
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end
    end

    { 'a StandardError' => ArgumentError, 'no StandardError' => SystemStackError }.each do |kind, error|
      context "when the hook raises an exception that is #{kind}" do
        let(:hook_error) { error }

        it 'draws the routes again before the caller gets the error' do
          expect { helper_object.site_install_theme('new') }.to raise_error(error, 'the hook raised')

          expect(draws.size).to eq(2)
        end
      end
    end
  end

  # The commit callback of the post type reloads the routes after the commit of the switch, from the
  # rows of the switch. The draw of the switch then ran one more trial, and drew the same routes again.
  describe 'a switch whose hook gives a post type a new slug' do
    let(:draws) { [] }
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_rename_post_type_on_active')
      CurrentRequest.site = @site
      PluginRoutes.reload
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end
    end

    it 'draws the routes one time, with the new slug and the new theme' do
      expect(PluginRoutes).to receive(:trial_draw).twice.and_call_original

      helper_object.site_install_theme('new')

      expect(draws.size).to eq(1)
      site = PluginRoutes.get_sites.find { |cached| cached.id == @site.id }
      expect(site.post_types.map(&:slug)).to include('probe_posts')
      expect(PluginRoutes.all_enabled_themes.pluck('key')).to eq(['new'])
    end
  end

  # The draw after the savepoint runs a trial again when another reload drew the routes in between. A
  # change outside the switch can fail that trial, and the switch then stays. In a transaction of the
  # caller, the error said that a transaction rolls the change back.
  describe 'a switch in a transaction of the caller whose draw after the savepoint fails' do
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_noted_on_active')
      CurrentRequest.site = @site
      allow(PluginRoutes).to receive(:trial_routes).and_wrap_original do |original|
        original.call.tap do
          PluginRoutes.reload
          break_the_routes
        end
      end
    end

    it 'gives an error that says that no transaction rolls the change back' do
      error = nil
      ActiveRecord::Base.transaction do
        helper_object.site_install_theme('new')
      rescue CamaleonCms::RouteDrawError => e
        error = e
      end

      expect(error).to have_attributes(in_transaction?: false, message: 'ArgumentError: broken plugin routes')
      expect(error.cause).to be_a(ArgumentError)
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('new')
    end
  end

  # The switch rolled back with no error, so the admin panel said that it updated the theme.
  describe 'a switch whose on_active hook raises ActiveRecord::Rollback' do
    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_rollback_on_active')
      PluginRoutes.reload
    end

    it 'raises an error and keeps the old theme' do
      state_before = theme_state

      get '/'

      expect(hook_log).to eq([[:install_error, rollback_error, 'default', 'default']])
      expect(theme_state).to eq(state_before)
      expect(group_count).to eq(0)
      expect(response.body).to include('themes/default/')
    end
  end

  # A before_commit callback runs at the commit of the switch, after the trial. Rails takes its
  # ActiveRecord::Rollback too, so the switch rolled back and the helper returned with no error.
  describe 'a switch whose before_commit callback raises ActiveRecord::Rollback' do
    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_noted_on_active')
      allow_any_instance_of(CamaleonCms::Theme).to receive(:before_committed!).and_raise(ActiveRecord::Rollback)
      PluginRoutes.reload
    end

    it 'raises an error and keeps the old theme' do
      state_before = theme_state

      get '/'

      expect(hook_log).to eq([[:install_error, rollback_error, 'default', 'default']])
      expect(theme_state).to eq(state_before)
      expect(response.body).to include('themes/default/')
    end
  end

  # Rails rolls the switch back for an exception of any class. The helper gave the old theme back only for a
  # StandardError or a ScriptError, so the request kept the new theme after another exception.
  describe 'a switch whose on_active hook raises an exception that is no StandardError' do
    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_stack_error_on_active')
      PluginRoutes.reload
    end

    it 'keeps the old theme as the current theme of the request' do
      state_before = theme_state

      get '/'

      expect(hook_log).to eq([[:install_error, 'stack level too deep', 'default', 'default']])
      expect(theme_state).to eq(state_before)
      expect(response.body).to include('themes/default/')
    end
  end

  describe 'a switch whose on_active hook raises a ScriptError' do
    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_script_error_on_active')
      PluginRoutes.reload
    end

    it 'keeps the old theme as the current theme of the request' do
      state_before = theme_state

      get '/'

      expect(hook_log).to eq([[:install_error, 'not implemented', 'default', 'default']])
      expect(theme_state).to eq(state_before)
      expect(response.body).to include('themes/default/')
    end
  end

  # On PostgreSQL, a statement that fails stops the transaction, also when the code rescues its error. Each
  # later read in that transaction fails, and its commit rolls back with no error. SQLite does not stop a
  # transaction, so a stub fails each read in a transaction that an example marks as stopped.
  describe 'a switch whose transaction the database stops' do
    let(:stopped_error) { 'PG::InFailedSqlTransaction: the transaction is stopped' }

    before do
      stopped = stopped_transactions
      error = stopped_error
      connection = ActiveRecord::Base.connection
      allow(connection).to receive(:select_all).and_wrap_original do |original, *args, **options|
        raise ActiveRecord::StatementInvalid, error if stopped.any? { |t| t.equal?(connection.current_transaction) }

        original.call(*args, **options)
      end
    end

    shared_examples 'a switch that the database stopped' do
      it 'raises an error and keeps the old theme' do
        state_before = theme_state

        get '/'

        expect(hook_log).to eq([[:install_error, stopped_error, 'default', 'default']])
        expect(theme_state).to eq(state_before)
        expect(response.body).to include('themes/default/')
      end
    end

    context 'when the hook leaves the transaction stopped' do
      before do
        probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_stopped_on_active')
        PluginRoutes.reload
      end

      it_behaves_like 'a switch that the database stopped'
    end

    # A route file can read the database. In a transaction that the hook stopped, the read before the trial
    # fails first. So the caller gets the error of the database, not an error of the routes.
    context 'when the hook leaves the transaction stopped and a route file reads the database' do
      before do
        break_the_routes('CamaleonCms::Site.first')
        probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_stopped_on_active')
        PluginRoutes.reload
      end

      it_behaves_like 'a switch that the database stopped'
    end

    # get_sites rescues the error of its read, for example a statement timeout, so the trial goes on.
    context 'when a read of the trial stops the transaction' do
      before do
        switches = switch_transactions
        stopped = stopped_transactions
        error = stopped_error
        allow(PluginRoutes).to receive(:stored_sites).and_wrap_original do |original|
          current = ActiveRecord::Base.connection.current_transaction
          if switches.any? { |t| t.equal?(current) }
            stopped << current
            raise ActiveRecord::StatementInvalid, error
          end

          original.call
        end
        probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_noted_on_active')
        PluginRoutes.reload
      end

      it_behaves_like 'a switch that the database stopped'
    end
  end

  # A commit callback can raise after the commit of the switch, and the site then has the new theme. The
  # switch runs after the render: the views of the request are the views of the old theme.
  describe 'a switch whose commit callback raises' do
    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_post_type_on_active',
                  front_hook: 'front_after_load')
      allow_any_instance_of(CamaleonCms::PostType).to receive(:settle_routes)
        .and_raise(ActiveRecord::ActiveRecordError, 'commit callback')
      PluginRoutes.reload
    end

    it 'keeps the new theme as the current theme of the request' do
      get '/'

      expect(hook_log).to eq([[:install_error, 'commit callback', 'new', 'new']])
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('new')
    end
  end

  # The error of the commit callback skipped the draw of the switch. Here no hook draws the routes, so the
  # site had the new theme, and PluginRoutes gave the old theme to each thread.
  describe 'a switch whose commit callback raises, with no draw by a hook' do
    let(:draws) { [] }

    before do
      probe_hooks(front_switch: 'probe_switch_and_rescue', on_active: 'probe_noted_on_active',
                  front_hook: 'front_after_load')
      allow_any_instance_of(CamaleonCms::Theme).to receive(:forget_written_metas_options)
        .and_raise(ActiveRecord::ActiveRecordError, 'commit callback')
      PluginRoutes.reload
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end
    end

    it 'draws the routes of the new theme' do
      get '/'

      expect(hook_log).to eq([[:install_error, 'commit callback', 'new', 'new']])
      expect(draws.size).to eq(1)
      expect(PluginRoutes.all_enabled_themes.pluck('key')).to eq(['new'])
    end
  end

  # The switch reads the site before and after its trial, and no write between the two reads clears the
  # query cache. An answer from the cache raises no error in a transaction that the database stopped.
  describe 'the reads of a switch while the query cache is on' do
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_noted_on_active')
      CurrentRequest.site = @site
    end

    # The statements of the block: true for an answer from the query cache.
    def cached_statements
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        statements << (args.last[:cached] == true) unless args.last[:name] == 'SCHEMA'
      end
      yield
      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it 'reads the site from the database before and after the trial' do
      checks = []
      allow(helper_object).to receive(:cama_check_switch_transaction).and_wrap_original do |check|
        checks << cached_statements { check.call }
      end

      ActiveRecord::Base.cache { helper_object.site_install_theme('new') }

      expect(checks).to eq([[false], [false]])
    end
  end

  # After the error of a commit callback, the draw of the switch can fail too. Here another reload drew
  # the routes after the trial, and then a route file breaks. The caller must get the error of the
  # callback, so the error of the draw goes to the log.
  describe 'a switch whose commit callback raises, and whose draw fails' do
    let(:helper_object) do
      Class.new do
        include CamaleonCms::PluginsHelper
        include CamaleonCms::HooksHelper
      end.new
    end

    before do
      probe_hooks(on_active: 'probe_noted_on_active')
      CurrentRequest.site = @site
      allow_any_instance_of(CamaleonCms::Theme).to receive(:forget_written_metas_options)
        .and_raise(ActiveRecord::ActiveRecordError, 'commit callback')
      allow(PluginRoutes).to receive(:trial_routes).and_wrap_original do |original|
        original.call.tap do
          PluginRoutes.reload
          break_the_routes
        end
      end
      allow(Rails.logger).to receive(:error)
    end

    it 'gives the error of the callback, and logs the error of the draw' do
      expect(Rails.logger).to receive(:error)
        .with(/the routes of the theme switch were not drawn \(CamaleonCms::RouteDrawError: .*broken plugin routes/)

      expect { helper_object.site_install_theme('new') }
        .to raise_error(ActiveRecord::ActiveRecordError, 'commit callback')
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('new')
    end
  end
end
