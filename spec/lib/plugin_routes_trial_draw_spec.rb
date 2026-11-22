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
  end

  describe '.route_set' do
    it 'is the route set of the app when no trial runs' do
      expect(described_class.route_set).to equal(Rails.application.routes)
    end
  end
end
