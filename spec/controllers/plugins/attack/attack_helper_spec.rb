# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Plugins::Attack::AttackHelper, type: :controller do
  controller(ActionController::Base) do
    # rubocop:disable RSpec/DescribedClass
    include Plugins::Attack::AttackHelper
    # rubocop:enable RSpec/DescribedClass

    def index
      attack_app_before_load
    end

    def current_site
      nil
    end

    def attack_check_request; end

    def cama_get_session_id
      'attack-helper-session'
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  after do
    Rails.cache.delete('attack-helper-session')
  end

  it 'escapes cached ban messages before rendering them' do
    Rails.cache.write('attack-helper-session', '<script>alert(1)</script>')

    get :index

    expect(response.body).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
    expect(response.body).not_to include('<script>')
  end
end
