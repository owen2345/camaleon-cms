# frozen_string_literal: true

class CamaleonRecord < ActiveRecord::Base
  TRANSLATION_TAG_HIDE_MAP = { '<!--' => '!--', '-->' => '--!' }.freeze
  TRANSLATION_TAG_HIDE_REGEX = Regexp.new(TRANSLATION_TAG_HIDE_MAP.keys.map { |x| Regexp.escape(x) }.join('|')).freeze
  TRANSLATION_TAG_RESTORE_MAP = { '--!' => '-->', '!--' => '<!--' }.freeze
  TRANSLATION_TAG_RESTORE_REGEX =
    Regexp.new(TRANSLATION_TAG_RESTORE_MAP.keys.map { |x| Regexp.escape(x) }.join('|')).freeze

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

  # Return the current user for this thread/request context.
  # Uses ActiveSupport::CurrentAttributes (CurrentRequest.user)
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = CurrentRequest.user
  end

  # Authorization helpers that delegate to central Ability (CanCan)
  def can?(*args)
    # Return false if no user or site context (e.g., background jobs, console)
    return false if current_user.nil? || current_site.nil?

    ability.can?(*args)
  end

  def ability
    # Memoize Ability per request to avoid repeated DB queries and object instantiation.
    # In tests that modify role meta mid-request, call reset_ability to invalidate cache.
    @ability ||= CamaleonCms::Ability.new(current_user, current_site)
  end

  # Reset cached ability instance (useful in tests when role meta changes)
  def reset_ability
    @ability = nil
  end

  # current_site memoized from the CurrentRequest.site
  def current_site
    return @current_site if defined?(@current_site) && @current_site.present?

    @current_site = CurrentRequest.site
  end
end
