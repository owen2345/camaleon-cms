# frozen_string_literal: true

# Rails clears the route set of the app before it loads the route files. A route file that raises an
# error then leaves the app with no routes. PluginRoutes loads the route files of Camaleon into an
# empty route set first, so a draw that fails changes nothing.
RSpec.describe PluginRoutes do
  init_site

  def reload_and_rescue
    described_class.reload
  rescue StandardError, ScriptError
    nil
  end

  before { described_class.reload }

  describe '.reload' do
    it 'keeps each route of the app when the route file of a plugin raises an error' do
      names = app_route_names
      break_the_routes

      reload_and_rescue

      expect(names).to include(:cama_admin_dashboard)
      expect(app_route_names).to eq(names)
    end

    it 'keeps the site list and the cached values when the route file of a plugin raises an error' do
      sites = described_class.get_sites
      described_class.cache_variable('probe', 'kept')
      break_the_routes

      reload_and_rescue

      expect(described_class.loaded_sites).to equal(sites)
      expect(described_class.cache_variable('probe')).to eq('kept')
    end

    it 'raises CamaleonCms::RouteDrawError, which names the error of the route file' do
      break_the_routes

      expect { described_class.reload }.to raise_error(CamaleonCms::RouteDrawError) do |error|
        expect(error.message).to eq('ArgumentError: broken plugin routes')
        expect(error.cause).to be_a(ArgumentError)
        expect(error).not_to be_in_transaction
      end
    end

    context 'when the route file has a syntax error' do
      it 'raises CamaleonCms::RouteDrawError with the SyntaxError as its cause, and keeps the routes' do
        names = app_route_names
        break_the_routes("get 'broken' =>")

        expect { described_class.reload }.to raise_error(CamaleonCms::RouteDrawError, /\ASyntaxError: /) do |error|
          expect(error.cause).to be_a(SyntaxError)
        end
        expect(app_route_names).to eq(names)
      end
    end

    it 'says that a transaction was open at the failure' do
      break_the_routes

      ActiveRecord::Base.transaction do
        expect { described_class.reload }.to raise_error(CamaleonCms::RouteDrawError) do |error|
          expect(error).to be_in_transaction
        end
      end
    end

    it 'draws the routes of the app one time, and reads the sites one time, when each route file can be drawn' do
      draws = 0
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws += 1
        draw.call
      end
      expect(CamaleonCms::Site).to receive(:includes).with(:metas, :post_types).once.and_call_original

      described_class.reload

      expect(draws).to eq(1)
    end

    # The first trial reads the stored name. Then a second reload draws the routes with a new name.
    it 'runs its trial again when another reload drew the routes after the trial' do
      other_site = create(:site, name: 'Stored name')
      first_trial = true
      allow(described_class).to receive(:trial_draw).and_wrap_original do |trial|
        data = trial.call
        if first_trial
          first_trial = false
          CamaleonCms::Site.where(id: other_site.id).update_all(name: 'New name') # rubocop:disable Rails/SkipsModelValidations
          described_class.reload
        end
        data
      end

      described_class.reload

      expect(described_class.get_sites.find { |site| site.id == other_site.id }.name).to eq('New name')
    end
  end

  describe '.check_routes' do
    it 'raises CamaleonCms::RouteDrawError, and draws no route of the app, when a route file raises an error' do
      names = app_route_names
      break_the_routes
      expect(Rails.application).not_to receive(:reload_routes!)

      expect { described_class.check_routes }.to raise_error(CamaleonCms::RouteDrawError, /broken plugin routes/)
      expect(app_route_names).to eq(names)
    end

    it 'raises no error, draws no route of the app and keeps the cached data when each route file can be drawn' do
      sites = described_class.get_sites
      described_class.cache_variable('probe', 'kept')
      expect(Rails.application).not_to receive(:reload_routes!)

      expect(described_class.check_routes).to be_nil

      expect(described_class.loaded_sites).to equal(sites)
      expect(described_class.cache_variable('probe')).to eq('kept')
    end

    # A trial reads with no query cache. Before Rails 7.2, uncached asks for a database connection, and
    # a database that is not there raises an error.
    it 'runs the trial with the query cache when a read with no query cache gets no connection' do
      allow(CamaleonCms::Site).to receive(:uncached).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect(described_class.check_routes).to be_nil
    end

    # A route file can raise an error of Active Record in the trial. That error is the error of the
    # trial, so the trial does not run again with the query cache.
    it 'raises CamaleonCms::RouteDrawError with the Active Record error of a route file as its cause' do
      break_the_routes("raise ActiveRecord::StatementInvalid, 'the route file read failed'")

      expect { described_class.check_routes }.to raise_error(CamaleonCms::RouteDrawError) do |error|
        expect(error.cause).to be_a(ActiveRecord::StatementInvalid)
      end
    end
  end

  # Code can check the routes in a transaction, and reload them after it with the data of that check.
  describe '.trial_routes' do
    let(:draws) { [] }

    before do
      allow(Rails.application).to receive(:reload_routes!).and_wrap_original do |draw|
        draws << :draw
        draw.call
      end
    end

    it 'gives a trial that a reload draws the routes of the app from, with no trial of its own' do
      trial = described_class.trial_routes
      expect(described_class).not_to receive(:trial_draw)

      described_class.reload(trial: trial)

      expect(draws.size).to eq(1)
    end

    it 'raises CamaleonCms::RouteDrawError, and draws no route of the app, when a route file raises an error' do
      break_the_routes

      expect { described_class.trial_routes }.to raise_error(CamaleonCms::RouteDrawError, /broken plugin routes/)
      expect(draws).to be_empty
    end

    # The data of the other reload can be newer than the data of the trial.
    it 'makes the reload run a trial again when a reload of another thread drew the routes after the trial' do
      trial = described_class.trial_routes
      Thread.new { described_class.reload }.join
      expect(described_class).to receive(:trial_draw).once.and_call_original

      described_class.reload(trial: trial)

      expect(draws.size).to eq(2)
    end

    # The trial read the rows as its transaction saw them. After the commit, the database can hold a
    # newer row of another connection. Here the example stores a name with no callback.
    it 'makes the reload run a trial again when the transaction of the trial committed' do
      trial = nil
      ActiveRecord::Base.transaction(requires_new: true) { trial = described_class.trial_routes }
      CamaleonCms::Site.where(id: @site.id).update_all(name: 'Stored after the trial') # rubocop:disable Rails/SkipsModelValidations
      expect(described_class).to receive(:trial_draw).once.and_call_original

      described_class.reload(trial: trial)

      expect(described_class.get_sites.find { |site| site.id == @site.id }.name).to eq('Stored after the trial')
      expect(draws.size).to eq(1)
    end

    # A later transaction of the thread is not the transaction of the trial. A trial in it reads the newer
    # row, so the reload must not draw from the old trial there.
    it 'makes the reload run a trial again in a later transaction, when the transaction of the trial committed' do
      trial = nil
      ActiveRecord::Base.transaction(requires_new: true) { trial = described_class.trial_routes }
      CamaleonCms::Site.where(id: @site.id).update_all(name: 'Stored after the trial') # rubocop:disable Rails/SkipsModelValidations
      expect(described_class).to receive(:trial_draw).once.and_call_original

      ActiveRecord::Base.transaction(requires_new: true) do
        described_class.reload(trial: trial)

        expect(described_class.get_sites.find { |site| site.id == @site.id }.name).to eq('Stored after the trial')
      end
      expect(draws.size).to eq(1)
    end

    # In a transaction of the caller that is still open, the release of a savepoint is no commit. So the
    # reload runs no trial again.
    it 'draws from a trial of a savepoint, with no trial of its own, in the transaction around it' do
      ActiveRecord::Base.transaction(requires_new: true) do
        trial = nil
        ActiveRecord::Base.transaction(requires_new: true) { trial = described_class.trial_routes }
        expect(described_class).not_to receive(:trial_draw)

        described_class.reload(trial: trial)
      end

      expect(draws.size).to eq(1)
    end

    # The trial read a row that the rollback removed. A reload that drew from that trial gave the row to
    # each thread.
    it 'makes the reload run a trial again when the transaction of the trial rolled back' do
      stored_slug = @site.slug
      trial = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        CamaleonCms::Site.find(@site.id).update!(slug: 'renamed.example.test')
        trial = described_class.trial_routes
        raise ActiveRecord::Rollback
      end

      described_class.reload(trial: trial)

      expect(described_class.get_sites.find { |site| site.id == @site.id }.slug).to eq(stored_slug)
      expect(draws.size).to eq(1)
    end

    # A commit that loses the connection leaves the state of its transaction invalidated: the database
    # can hold the change or not. The example makes the release of the savepoint fail.
    it 'makes the reload run a trial again when the commit of the transaction of the trial lost the connection' do
      connection = ActiveRecord::Base.connection
      allow(connection).to receive(:release_savepoint).and_raise(ActiveRecord::ConnectionFailed, 'gone')
      # Rails throws the connection away after such a commit, and the example still needs it.
      allow(connection).to receive(:throw_away!)
      trial = nil
      expect do
        ActiveRecord::Base.transaction do
          connection.materialize_transactions
          trial = described_class.trial_routes
        end
      end.to raise_error(ActiveRecord::ConnectionFailed)
      expect(described_class).to receive(:trial_draw).once.and_call_original

      described_class.reload(trial: trial)

      expect(draws.size).to eq(1)
    end

    # The draw of this thread read the stored rows after the trial, so a draw from the trial adds nothing.
    it 'draws no routes again when this thread drew the routes after the trial, with no open transaction' do
      trial = described_class.trial_routes
      described_class.reload
      expect(described_class).not_to receive(:trial_draw)

      described_class.reload(trial: trial)

      expect(draws.size).to eq(1)
    end

    # A draw in a transaction can read rows that a rollback removes.
    it 'makes the reload run a trial again when this thread drew the routes after the trial, in a transaction' do
      trial = described_class.trial_routes
      ActiveRecord::Base.transaction(requires_new: true) { described_class.reload }
      expect(described_class).to receive(:trial_draw).once.and_call_original

      described_class.reload(trial: trial)

      expect(draws.size).to eq(2)
    end

    # The older trial lacks a row that the newer trial read.
    it 'makes the reload run a trial again when this thread drew the routes from an older trial' do
      older = described_class.trial_routes
      trial = described_class.trial_routes
      described_class.reload(trial: older)
      expect(described_class).to receive(:trial_draw).once.and_call_original

      described_class.reload(trial: trial)

      expect(draws.size).to eq(2)
    end

    # Another reload can draw the routes while the trial runs, and its data can be newer than the data
    # of the trial. So the trial counts the reloads before it reads its data.
    it 'makes the reload run a trial again when another reload drew the routes during the trial' do
      first_trial = true
      allow(described_class).to receive(:trial_draw).and_wrap_original do |trial_draw|
        data = trial_draw.call
        if first_trial
          first_trial = false
          Thread.new { described_class.reload }.join
        end
        data
      end
      trial = described_class.trial_routes
      expect(described_class).to receive(:trial_draw).once.and_call_original

      described_class.reload(trial: trial)

      expect(draws.size).to eq(2)
    end
  end

  describe '.route_set' do
    it 'is the route set of the app when no trial runs' do
      expect(described_class.route_set).to equal(Rails.application.routes)
    end
  end
end
