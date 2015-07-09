Dir[Rails.root.join("#{Rails.root}/app/helpers/*.rb")].each { |f| require f }
namespace :work do
  include ApplicationHelper
  include Rails.application.routes.url_helpers


  desc "Debug test"
  task :subscribers, [:typee] => :environment do |t, args|
    args.with_defaults(:typee => "data")

    type = args.typee # 'selweb'

    Rails.application.routes.default_url_options[:host] = _dev ? 'www.local.com:3007' : 'www.server.com'

    subscriptors = Subscriber.actived.all


  end

end