# frozen_string_literal: true

module CamaleonCms
  module Metas
    extend ActiveSupport::Concern

    # Raised by set_metas/set_options for a container that is present but not a set of fields (an
    # array of pairs, a scalar). The writers iterate a container key by key, so such input would be
    # stored pair by pair past every hash-shaped check, or raise deep inside on to_sym; it is refused
    # up front and nothing is written.
    class InvalidContainer < ArgumentError; end

    # how the text column cast a boolean before booleans were stored as their JSON literal
    LEGACY_BOOLEANS = { 't' => true, 'f' => false }.freeze
    private_constant :LEGACY_BOOLEANS

    # What a JSON text can open with, after its whitespace, on every supported json release: an object, an
    # array, a string, a comment, a number, true, false or null. Text opening with anything else holds none.
    JSON_TEXT_OPENING = %r{\A\s*[\[\{"/\-\dtfn]}
    private_constant :JSON_TEXT_OPENING

    included do
      # options and metas auto save support
      attr_accessor :data_options
      attr_accessor :data_metas

      # refused before any statement, as the writers refuse it after the row would have been written
      before_save   :refuse_invalid_queued_containers
      after_create  :save_metas_options
      before_update :save_metas_options
      # a write undone with its transaction is queued again for the next save
      after_rollback :requeue_metas_options
      after_commit :forget_written_metas_options
    end

    # JSON for a Hash or Array value, with one entry per key however each key was written: a String key
    # replaces its Symbol twin, at any depth (json 3 refuses to generate both, json 2 stored both)
    def self.generate_json(value)
      JSON.generate(indifferent_json_value(value))
    end

    # a parsed Hash, or the Hashes in a parsed Array, read by either key type
    def self.indifferent_json_value(value)
      case value
      when Hash then value.with_indifferent_access
      when Array then value.map { |item| indifferent_json_value(item) }
      else value
      end
    end

    # Adds the meta for key, or updates it, and returns the value passed
    def set_meta(key, value)
      key_str = key.to_s
      stored = store_meta(key_str, value)
      # memoize what a reload reads for the stored value, so the writing instance reads as a reloaded record
      memoize_written_meta(key_str, value, stored)
      value
    end

    # The value stored for key, as a freshly loaded record reads it, memoized per instance, nil for a key
    # with no row. Each call applies its own default, outside the memo, when the meta has no value: no row,
    # or a stored null or empty string.
    def get_meta(key, default = nil)
      key_str = key.to_s
      cached = cama_fetch_cache("meta_#{key_str}") { read_meta_row(key_str) }
      meta_value_absent?(cached) ? default : cached
    end

    # delete meta
    def delete_meta(key)
      key_str = key.to_s
      # Through the association, so the loaded copies of the stored rows and the metas built but not yet
      # saved leave the record too: get_meta reads loaded metas, and a save stores built ones. The stored
      # rows an unsaved record holds belong to another record, and its query scope is empty, so only its
      # built metas are dropped.
      built = metas.target.select { |m| m.new_record? && m.key == key_str }
      metas.destroy(*built, *metas.where(key: key_str))
      cama_remove_cache("meta_#{key_str}")
    end

    # return configurations for current object, sample: {"type":"post_type","object_id":"127"}
    # The indifferent hash the record's options parse to, on the writing instance as on a freshly loaded
    # record, so a String key and its Symbol twin read the same option: the hash get_meta memoizes, which
    # the option writers update. A value that is not a JSON object (no options row, a legacy or corrupt row,
    # a JSON string, even one whose text is an object, nil) reads as a new empty hash on each read, so every
    # reader and writer works on the record and a change made to that hash without a writer is not stored;
    # the row, if any, is replaced the next time an option is written.
    def options(meta_key = '_default')
      data = get_meta(meta_key)
      data.is_a?(ActiveSupport::HashWithIndifferentAccess) ? data : ActiveSupport::HashWithIndifferentAccess.new
    end
    alias cama_options options

    # add configuration for current object
    # key: attribute name
    # value: attribute value
    # meta_key: (String) name of the meta attribute
    # sample: mymodel.set_custom_option("my_settings", "color", "red")
    def set_option(key, value = nil, meta_key = '_default')
      return if key.nil?

      write_options(meta_key) { |data| data[key] = fix_meta_var(value) }
      value
    end

    # return configuration for current object
    # key: attribute name
    # default: if the attribute doesn't exist, or its value is null or "", return default
    # return value for attribute
    def get_option(key = nil, default = nil, meta_key = '_default')
      values = cama_options(meta_key)
      return default if key.nil?

      key = key.to_sym
      values.key?(key) && !meta_value_absent?(values[key]) ? values[key] : default
    end

    # delete attribute from configuration
    def delete_option(key, meta_key = '_default')
      return if key.nil?

      key = key.to_sym
      write_options(meta_key) { |values| values.delete(key) if values.key?(key) }
    end

    # set multiple configurations
    # h: {ket1: "sdsds", ff: "fdfdfdfd"}
    def set_options(h = {}, meta_key = '_default')
      return if h.blank?

      refuse_invalid_container!(h)
      write_options(meta_key) do |data|
        PluginRoutes.fixActionParameter(h).to_sym.each do |key, value|
          data[key] = fix_meta_var(value)
        end
      end
    end
    alias set_multiple_options set_options

    # save multiple metas
    # sample: set_metas({name: 'Owen', email: 'owenperedo@gmail.com'})
    def set_metas(data_metas)
      return if data_metas.blank?

      refuse_invalid_container!(data_metas)
      data_metas.each do |key, value|
        set_meta(key, value)
      end
    end

    # A copy is a new record with no write behind it: it starts without the record of the original's
    # last write, which a rollback of that write's transaction would otherwise queue on the copy, and
    # with queues of its own, so a value queued on one is not queued on the other.
    def initialize_dup(other)
      @written_metas_options = nil
      @created_record_metas_in_memory = false
      self.data_options = data_options.deep_dup
      self.data_metas = data_metas.deep_dup
      super
    end

    # Write the metas and options a record was given in data_metas and data_options, then clear them:
    # a later save of this instance must not write them again over values set since. The metas go
    # first, so that a `_default` meta, which is the options row itself, does not replace the options
    # written after it; they merge into it instead.
    # sample: Site.first.post_types.create(name: 'Catalog', slug: 'catalog', data_options: { has_category: true })
    def save_metas_options
      return if data_options.blank? && data_metas.blank?

      # The metas scope memoized before the INSERT names no owner, so a write would miss the row the
      # write before it created; the metas autosave rebuilds it too, but runs after this callback.
      metas.proxy_association.reset_scope if previously_new_record?
      # While the creating save writes the queues, every row of the record is in memory: the metas
      # built before the save and the rows this write creates, since nothing else has written for an
      # id this INSERT assigned. Reads and lookups take them from there instead of querying.
      @created_record_metas_in_memory = previously_new_record?
      set_metas(data_metas)
      set_options(data_options)
      @written_metas_options = [data_options, data_metas, current_transaction_state, previously_new_record?]
      self.data_options = nil
      self.data_metas = nil
    ensure
      @created_record_metas_in_memory = false
    end

    private

    # Checks and stores value for key, and returns the form a read returns for it. When the write raises,
    # refused or failed, a value this instance handed out for key, changed in place and written back, reads
    # what is stored again.
    def store_meta(key_str, value)
      fixed_value = fix_meta_value(value)
      stored = stored_form_of(fixed_value)
      check_meta_write(key_str, stored)
      write_meta_row(key_str, fixed_value)
      stored
    rescue StandardError
      reread_handed_out_meta(key_str, value)
      raise
    end

    # Writes fixed_value, the stored form of a value, to the row of key
    def write_meta_row(key_str, fixed_value)
      # Check if the parent object has been saved to the database yet
      if persisted?
        # A meta built before the first save is still pending during the after_create callbacks, and the
        # metas autosave inserts it afterwards: update it instead of adding a second row for the key.
        # Otherwise update the lowest id when a key has several rows: the one get_meta reads.
        pending_record = metas.target.find { |m| m.new_record? && m.key == key_str }
        if pending_record
          pending_record.value = fixed_value
        elsif (meta_record = meta_row(key_str, stored_only: true))
          meta_record.update(value: fixed_value)
        else
          metas.create(key: key_str, value: fixed_value)
        end
      else
        # In-Memory Fallback: Find an existing unsaved item in the array collection,
        # or build a brand new unsaved record on the association.
        meta_record = metas.find { |m| m.key == key_str }

        if meta_record
          meta_record.value = fixed_value
        else
          metas.build(key: key_str, value: fixed_value)
        end
      end
    end

    # What the row of key reads as, nil for a key with no row
    def read_meta_row(key_str)
      option = meta_row(key_str)
      stored_meta_value(option) if option
    end

    # A value this instance handed out for key, the memoized hash, list or text itself, changed in place and
    # written back by a write that raised, takes what the key's row reads as again, in place when it is a
    # hash or a list that is not frozen, so the instance does not read a change nothing stored. When the row
    # cannot be read either, the memo is dropped for the next read to take it.
    def reread_handed_out_meta(key_str, value)
      memo_key = "meta_#{key_str}"
      return unless [Hash, Array, String].any? { |type| value.is_a?(type) } && value.equal?(cama_get_cache(memo_key))

      memoize_written_meta(key_str, value, read_meta_row(key_str))
    rescue StandardError
      cama_remove_cache(memo_key)
    end

    # The value a stored row reads as (stored_form_of). A boolean an earlier release stored as the column's
    # 't' or 'f' reads as the boolean and is stored again as its JSON literal so the next read parses it;
    # that write is made while reading, so where it fails, because writes are prevented or for any other
    # reason, the row is left for a later read.
    def stored_meta_value(option)
      return stored_form_of(option.value) unless LEGACY_BOOLEANS.key?(option.value)

      boolean = LEGACY_BOOLEANS.fetch(option.value)
      begin
        option.update_column(:value, boolean.to_s) # rubocop:disable Rails/SkipsModelValidations
      rescue StandardError
        nil
      end
      boolean
    end

    # What a read returns for the text a row holds, or for the value fix_meta_value produced for one: its
    # JSON parsed, with the Hashes in it read by either key type at any depth (a key an older write stored
    # twice keeps its last value, as json 2 read it), a legacy 't' or 'f' as the boolean, a plain String copy
    # of the text when it holds no JSON, taken without a parse when the text cannot open a JSON text, and nil
    # for a null row. set_meta memoizes this form, so the writing instance reads what a freshly loaded record
    # reads: for text, the plain String the text column casts, neither the caller's object nor html_safe. The
    # text is taken outside the rescue, so a value whose text cannot be taken raises its own error.
    def stored_form_of(stored)
      stored_form_of_text(stored.to_s) unless stored.nil?
    end

    # The form a read returns for text: the value its JSON holds, or a plain String copy of the text when it
    # holds none, text that is not valid in its encoding included
    def stored_form_of_text(text)
      return String.new(text) unless text.match?(JSON_TEXT_OPENING)

      parsed = LEGACY_BOOLEANS.fetch(text) { JSON.parse(text, allow_duplicate_key: true) }
      CamaleonCms::Metas.indifferent_json_value(parsed)
    rescue StandardError
      String.new(text)
    end

    # Called by set_meta with the key, as a String, and the form a read returns for the value it is about to
    # store, before anything is written; a model refuses a write by raising here. Nothing is refused here.
    def check_meta_write(_key, _stored); end

    # The option writers change a copy of the options this instance holds, down to their nested values, and
    # store it with set_meta. The options take the stored form only once it is stored, so a write that
    # raises, refused or failed, leaves them as they were and the instance keeps reading what is stored.
    # They return the options the instance reads afterwards, the hash `options` returns, on a first options
    # write too: the options handed out take in place the form set_meta memoized for the copy, and are
    # memoized in its stead, so a hash `options` returned keeps reading every option write, unless it is
    # frozen, when the stored form stays memoized.
    def write_options(meta_key)
      options = cama_options(meta_key)
      changed = options.deep_dup
      yield changed
      set_meta(meta_key, changed)
      memo_key = "meta_#{meta_key}"
      stored = cama_get_cache(memo_key)
      return stored if options.frozen? || !stored.instance_of?(options.class)

      cama_set_cache(memo_key, options.replace(stored))
    end

    # Memoizes for key what a reload reads for the value written. When the value written is the Hash or the
    # Array memoized for key, the one this instance handed out, the memo takes that form in place and stays
    # memoized, so every reference to it keeps reading the record; otherwise, a frozen memo included, the
    # stored form is memoized apart from the value written, which is left as passed. A String memo is never
    # changed in place, since it may carry the translations String#translate memoized on it.
    def memoize_written_meta(key_str, written, stored)
      memo_key = "meta_#{key_str}"
      memo = cama_get_cache(memo_key)
      in_place = memo.equal?(written) && (memo.is_a?(Hash) || memo.is_a?(Array)) && !memo.frozen? &&
                 stored.is_a?(memo.class)
      cama_set_cache(memo_key, in_place ? memo.replace(stored) : stored)
    end

    # The state of the transaction running now, if any: the one a write belongs to, whose rollback
    # undoes it. Its state is marked rolled back with the outermost transaction's too.
    def current_transaction_state
      transaction = self.class.connection.current_transaction
      transaction.state if transaction.respond_to?(:state)
    end

    # Refill data_options and data_metas from the last write when the transaction that ran it is rolled
    # back, so the next save of this instance writes them; values queued since are kept, and a rollback
    # of a later transaction leaves the write, which stands, consumed.
    def requeue_metas_options
      options, metas, state, created = @written_metas_options
      return unless state&.rolledback?

      @written_metas_options = nil
      self.data_options = options if data_options.blank?
      self.data_metas = metas if data_metas.blank?
      forget_rolled_back_metas(created)
    end

    # The rows the rolled-back transaction wrote are gone while the metas in memory still claim them.
    # A record whose creation was rolled back had every meta of its written there: they are built again,
    # so the next save stores them (the record's own state is restored after this callback, so the
    # write remembers whether it created the record). A record that existed keeps its earlier rows, so
    # its metas and the values cached from them are dropped and read again on demand.
    def forget_rolled_back_metas(created)
      if created
        built = metas.target.map { |meta| { key: meta.key, value: meta.value } }
        metas.reset
        built.each { |attributes| metas.build(attributes) }
      else
        metas.reset
        cama_clear_cache
      end
    end

    def forget_written_metas_options
      @written_metas_options = nil
    end

    # A data_options or data_metas value that is present but not a set of fields is refused before the
    # INSERT or UPDATE, with the writers' error, so no row is left behind it; a blank one is ignored.
    def refuse_invalid_queued_containers
      refuse_invalid_container!(data_options) if data_options.present?
      refuse_invalid_container!(data_metas) if data_metas.present?
    end

    def refuse_invalid_container!(container)
      return if container.is_a?(Hash) || container.is_a?(ActionController::Parameters)

      raise InvalidContainer, "metas and options must be a set of fields, not #{container.class}"
    end

    # The row of key a read takes: the lowest id among the key's rows, from the metas in memory when they are
    # loaded or complete, a meta built and not saved yet among them, and from the database otherwise. With
    # stored_only, the stored row a write updates, leaving out a built meta, which a write sets in place.
    def meta_row(key_str, stored_only: false)
      if metas.loaded? || created_record_metas_in_memory?
        metas.target.select { |m| m.key == key_str && (!stored_only || m.persisted?) }.min_by { |m| m.id.to_i }
      else
        metas.where(key: key_str).order(:id).first
      end
    end

    def created_record_metas_in_memory?
      @created_record_metas_in_memory == true
    end

    # A meta or option with no value: no row or entry, one stored as null, or an empty string. Every read
    # that takes a default returns it for these, on the writing instance and on a freshly loaded record.
    def meta_value_absent?(value)
      value.nil? || value == ''
    end

    # The stored form of a value: JSON for a container; for a boolean its JSON literal, which reads back as
    # the boolean where the text column would store 't' or 'f', a String every reader takes as present; and
    # for a value whose text is 't' or 'f', a String or a Symbol, its JSON string, which reads back as that
    # String, where the bare letter the column would store reads as the boolean an earlier release stored.
    def fix_meta_value(value)
      changed_value = if value.is_a?(ActionController::Parameters)
                        value.to_json
                      elsif value.is_a?(Array) || value.is_a?(Hash)
                        CamaleonCms::Metas.generate_json(value)
                      else
                        value
                      end
      changed_value = fix_meta_var(changed_value)
      return changed_value.to_s if [true, false].include?(changed_value)

      text = changed_value.to_s
      LEGACY_BOOLEANS.key?(text) ? JSON.generate(text) : changed_value
    end

    # fix to detect type of the variable
    def fix_meta_var(value)
      value = value.to_var if value.is_a?(String)
      value
    end
  end
end
