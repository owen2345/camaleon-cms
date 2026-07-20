# frozen_string_literal: true

class CamaleonRecord < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
  # Sentinels used to shield HTML comment delimiters (the translation locale markers such as `<!--:en-->`)
  # from ActionController's sanitize(), which strips HTML comments. Private-Use-Area code points are used so
  # that plain text typed by a user can never be rewritten into a comment delimiter after sanitization: the
  # previous `!--`/`--!` tokens collided with ordinary text (e.g. "Read more !--"), so the restore pass would
  # inject stray `<!--`/`-->` into the output. The hide map also strips any raw sentinel characters supplied
  # in the input, so they cannot be smuggled through to become delimiters on restore.
  TRANSLATION_TAG_HIDE_SENTINELS = { open: "\u{E000}", close: "\u{E001}" }.freeze
  TRANSLATION_TAG_HIDE_MAP = {
    '<!--' => TRANSLATION_TAG_HIDE_SENTINELS[:open],
    '-->' => TRANSLATION_TAG_HIDE_SENTINELS[:close],
    TRANSLATION_TAG_HIDE_SENTINELS[:open] => '',
    TRANSLATION_TAG_HIDE_SENTINELS[:close] => ''
  }.freeze
  TRANSLATION_TAG_HIDE_REGEX = Regexp.new(TRANSLATION_TAG_HIDE_MAP.keys.map { |x| Regexp.escape(x) }.join('|')).freeze
  TRANSLATION_TAG_RESTORE_MAP = {
    TRANSLATION_TAG_HIDE_SENTINELS[:open] => '<!--',
    TRANSLATION_TAG_HIDE_SENTINELS[:close] => '-->'
  }.freeze
  TRANSLATION_TAG_RESTORE_REGEX =
    Regexp.new(TRANSLATION_TAG_RESTORE_MAP.keys.map { |x| Regexp.escape(x) }.join('|')).freeze

  self.abstract_class = true

  def self.polymorphic_name
    return super unless name.to_s.start_with?('CamaleonCms::')

    name.demodulize
  end

  def self.polymorphic_class_for(name)
    super
  rescue NameError
    legacy_class = legacy_camaleon_polymorphic_class(name)
    return legacy_class if legacy_class
    return nil if legacy_polymorphic_marker?(name)

    raise
  end

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

  def self.legacy_camaleon_polymorphic_class(name)
    class_name = name.to_s
    return if class_name.blank?

    candidates = []

    unless class_name.include?('::')
      candidates << "CamaleonCms::#{class_name}"

      if class_name.include?('_')
        base_name = class_name.split('_').first
        candidates << "CamaleonCms::#{base_name}" if base_name.present?
      end

      candidates << CamaManager.get_user_class_name.to_s if class_name == 'User'
    end

    candidates << "CamaleonCms::#{class_name}" if class_name.include?('::') && !class_name.start_with?('CamaleonCms::')

    candidates.uniq.each do |candidate|
      next unless valid_constant_name?(candidate)

      klass = candidate.safe_constantize
      return klass if klass
    end

    nil
  end
  private_class_method def self.legacy_polymorphic_marker?(name)
    name.to_s.start_with?('_')
  end

  private_class_method def self.valid_constant_name?(name)
    name.to_s.match?(/\A[A-Z]\w*(::[A-Z]\w*)*\z/)
  end

  private_class_method :legacy_camaleon_polymorphic_class
end
