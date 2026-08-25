# frozen_string_literal: true

# The three front_cache spec files each drive the plugin helper through a bare host object that mixes
# in Plugins::FrontCache::FrontCacheHelper. They need different sets of controller accessors and a few
# stubbed collaborator methods, so this centralizes only the shared skeleton (the Class.new + include
# + attr_accessor) — each spec still declares exactly the accessors it needs, and any method overrides
# through the block.
module FrontCacheHostBuilder
  def front_cache_host_class(*accessors, &body)
    Class.new do
      include Plugins::FrontCache::FrontCacheHelper
      attr_accessor(*accessors)

      class_eval(&body) if body
    end
  end
end

RSpec.configure { |config| config.include FrontCacheHostBuilder }
