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

  # What a record memoized before its first save sits under keys built with no id, which no read builds once
  # the INSERT assigns one, so the save drops it rather than keep it for the instance's life
  after_create :forget_cache_memoized_without_id

  # Sanitize a value with ActionController's sanitize() while preserving translation locale markers
  # (<!--:xx-->). Shared by Post#sanitize_content and the NormalizeAttrs concern so the transform lives in
  # one place. Returns nil unchanged. `tags:`/`attributes:` default to nil, i.e. the sanitizer's own
  # allowlist, so NormalizeAttrs and other callers are unaffected; Post#content passes a widened list.
  def self.cama_sanitize_translatable(value, tags: nil, attributes: nil)
    return value if value.nil?

    options = {}
    options[:tags] = tags if tags
    options[:attributes] = attributes if attributes
    ActionController::Base.helpers.sanitize(
      value.to_s.gsub(TRANSLATION_TAG_HIDE_REGEX, TRANSLATION_TAG_HIDE_MAP), **options
    ).gsub(TRANSLATION_TAG_RESTORE_REGEX, TRANSLATION_TAG_RESTORE_MAP)
  end

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
    return unless @cama_cache_vars

    @cama_cache_vars.delete(cama_build_cache_key(key))
  end

  # drop every value memoized on this instance
  def cama_clear_cache
    @cama_cache_vars = nil
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
  def cama_build_cache_key(key, key_id = id)
    _key = "cama_cache_#{self.class.name}_#{key_id}_#{key}"
  end

  # A copy starts with its own empty cache: copies are new records, and sharing the original's would let
  # them read each other's values under their common nil-id keys
  def initialize_dup(other)
    cama_clear_cache
    super
  end

  # The cached values were read from the state reload replaces, so they go once it is replaced, and so
  # does the ability, whose role metas may have changed since; a reload that fails leaves the record, and
  # what it memoized from it, as they were.
  def reload(options = nil)
    super.tap do
      cama_clear_cache
      @ability = nil
    end
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

  # Memoized for the request, as building it queries the role and its metas; reload rebuilds it.
  def ability
    @ability ||= CamaleonCms::Ability.new(current_user, current_site)
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

  private

  def forget_cache_memoized_without_id
    without_id = cama_build_cache_key('', nil)
    @cama_cache_vars&.delete_if { |key, _value| key.start_with?(without_id) }
  end
end
