# frozen_string_literal: true

class CamaleonRecord < ActiveRecord::Base
  include ActiveRecordExtras::Relation

  self.abstract_class = true

  # save cache value for this key
  def cama_set_cache(key, val)
    @cama_cache_vars ||= {}
    @cama_cache_vars[cama_build_cache_key(key)] = val
    val
  end

  # remove cache value for this key
  def cama_remove_cache(key)
    @cama_cache_vars.delete(cama_build_cache_key(key))
  end

  # fetch the cache value for this key
  def cama_fetch_cache(key)
    @cama_cache_vars ||= {}
    _key = cama_build_cache_key(key)
    if @cama_cache_vars.key?(_key)
      # puts "*********** using model cache var: #{_key}"
    else
      @cama_cache_vars[_key] = yield
    end
    @cama_cache_vars[_key]
  end

  # return the cache value for this key
  def cama_get_cache(key)
    @cama_cache_vars ||= {}
    begin
      @cama_cache_vars[cama_build_cache_key(key)]
    rescue StandardError
      nil
    end
  end

  # internal helper to generate cache key
  def cama_build_cache_key(key)
    _key = "cama_cache_#{self.class.name}_#{id}_#{key}"
  end
end
