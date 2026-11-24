# frozen_string_literal: true

# site_install_theme read the transaction of the switch from ActiveRecord::Base.connection. That call leases a
# connection to the thread for good, so each theme switch raised where a host refuses such a lease.
RSpec.describe 'A theme switch where a host refuses a permanent connection lease' do
  include_context 'with theme hook probes'
  init_site

  let(:helper_object) do
    Class.new do
      include CamaleonCms::PluginsHelper
      include CamaleonCms::HooksHelper
    end.new
  end

  before do
    skip 'Rails 7.2 and later can refuse it' unless ActiveRecord.respond_to?(:permanent_connection_checkout)
    # The themes get no hook, so the helper needs no request and no user.
    probe_theme_hooks(Module.new, 'default' => {}, 'new' => {})
  end

  # The thread of an example holds its connection for good. A thread of its own holds no connection until a
  # query leases one for its length, as the thread of a request does.
  def in_a_thread_refusing_a_lease
    checkout = ActiveRecord.permanent_connection_checkout
    site = @site
    Thread.new do
      ActiveRecord.permanent_connection_checkout = :disallowed
      CurrentRequest.site = site
      yield
    ensure
      CurrentRequest.reset
      ActiveRecord.permanent_connection_checkout = checkout
    end.join
  end

  it 'switches the theme' do
    in_a_thread_refusing_a_lease { helper_object.site_install_theme('new') }

    expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('new')
  end
end
