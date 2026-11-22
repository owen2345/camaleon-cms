# frozen_string_literal: true

module CamaleonCms
  # The data that PluginRoutes reads for the routes, apart from the data that all threads share: the
  # site list, the values of cache_variable, and the text of the route files of plugins and themes.
  # A trial draw fills one, and PluginRoutes.reload then draws the routes of the app from it.
  class RouteData
    attr_accessor :sites
    attr_reader :cache, :sources

    def initialize
      @cache = {}
      @sources = {}
    end
  end
end
