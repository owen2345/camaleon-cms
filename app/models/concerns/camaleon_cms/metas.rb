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
      after_create  :remember_creating_transaction
      after_create  :save_created_metas_options
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
    # last write or creation, which a rollback of that transaction would otherwise apply to the copy, and
    # with queues of its own, so a value queued on one is not queued on the other.
    def initialize_dup(other)
      @written_metas_options = nil
      @creating_transaction_state = nil
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
      set_metas(data_metas)
      set_options(data_options)
      @written_metas_options = [data_options, data_metas, current_transaction_state]
      self.data_options = nil
      self.data_metas = nil
    end

    private

    # While the creating save writes the queues, every row of the record is in memory: the metas
    # built before the save and the rows this write creates, since nothing else has written for an
    # id this INSERT assigned. Reads and lookups take them from there instead of querying. An update
    # reads the database, the first one after a create included, during which previously_new_record?
    # still holds: another instance may have written rows since.
    def save_created_metas_options
      @created_record_metas_in_memory = true
      save_metas_options
    ensure
      @created_record_metas_in_memory = false
    end

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
        # Update the stored row, the lowest id when a key has several: the one get_meta reads, so a meta
        # built for the key and not saved yet cannot take the write from it. A meta built before the first
        # save is still pending while the creating save writes the queues, and the metas autosave inserts it
        # afterwards: with no stored row, update it instead of adding a second row for the key. A meta built
        # on a saved record waits for a save that may never come, so outside the creation a row is stored.
        if (meta_record = meta_row(key_str, stored_only: true))
          meta_record.update(value: fixed_value)
        elsif created_record_metas_in_memory? &&
              (pending_record = metas.target.find { |m| m.new_record? && m.key == key_str })
          pending_record.value = fixed_value
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
      memo = cama_get_cache(memo_key)
      return unless value.equal?(memo) && (memo.is_a?(Hash) || memo.is_a?(Array) || memo.is_a?(String))

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
    # reads: for text, the plain UTF-8 String the text column reads back, neither the caller's object nor
    # html_safe. A finite number is that form already, and is returned without its text being parsed back.
    # The text is taken outside the rescue, so a value whose text cannot be taken raises its own error.
    def stored_form_of(stored)
      return stored if stored.is_a?(Integer) || (stored.is_a?(Float) && stored.finite?)

      stored_form_of_text(stored.to_s) unless stored.nil?
    end

    # The form a read returns for text: the value its JSON holds, or the text as the column reads it back when
    # it holds none, text that is not valid in its encoding included
    def stored_form_of_text(text)
      return column_text(text) unless text.match?(JSON_TEXT_OPENING)

      parsed = LEGACY_BOOLEANS.fetch(text) { JSON.parse(text, allow_duplicate_key: true) }
      CamaleonCms::Metas.indifferent_json_value(parsed)
    rescue StandardError
      column_text(text)
    end

    # Text as the text column reads it back: a plain String copy, in UTF-8, the encoding the database stores
    # text in, when it can be transcoded to it, and as it is otherwise, text the database refuses to store
    def column_text(text)
      String.new(text).encode!(Encoding::UTF_8)
    rescue EncodingError
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
      key_str = meta_key.to_s
      memoize_stored_form(key_str, options, cama_get_cache("meta_#{key_str}"))
    end

    # Memoizes for key what a reload reads for the value written. When the value written is the Hash or the
    # Array memoized for key, the one this instance handed out, it takes that form in place as
    # memoize_stored_form has it; otherwise the stored form is memoized apart from the value written, which
    # is left as passed.
    def memoize_written_meta(key_str, written, stored)
      memo = cama_get_cache("meta_#{key_str}")
      memoize_stored_form(key_str, (memo if memo.equal?(written)), stored)
    end

    # Memoizes stored, the form a read returns for what key holds, in held, the Hash or the Array this
    # instance handed out for key, which takes it in place and stays memoized, so every reference to it keeps
    # reading the record; otherwise, a frozen one, one that stored does not fit or none held, stored itself.
    # A String is never changed in place, since it may carry the translations String#translate memoized on
    # it. Returns what it memoizes.
    def memoize_stored_form(key_str, held, stored)
      in_place = (held.is_a?(Hash) || held.is_a?(Array)) && !held.frozen? && stored.is_a?(held.class)
      cama_set_cache("meta_#{key_str}", in_place ? take_stored_form(held, stored) : stored)
    end

    # Changes held in place to hold stored, keeping each value it already holds in its stored form, so a hash
    # or a list taken from it keeps reading the record across writes of the other values, as 2.9.4's option
    # writers, which changed only the option written, left them, and a hash keeps its default
    def take_stored_form(held, stored)
      if held.is_a?(Hash)
        held.keep_if { |key, _value| stored.key?(key) }
        stored.each { |key, value| held[key] = value unless held.key?(key) && same_stored_form?(held[key], value) }
      else
        held.replace(stored.each_with_index.map { |value, i| same_stored_form?(held[i], value) ? held[i] : value })
      end
      held
    end

    # Whether held is already value, in its stored form: the same class and value at every depth
    def same_stored_form?(held, value)
      return false unless held.instance_of?(value.class) && (!value.respond_to?(:size) || held.size == value.size)

      case value
      when Hash then value.all? { |key, item| held.key?(key) && same_stored_form?(held[key], item) }
      when Array then value.each_index.all? { |i| same_stored_form?(held[i], value[i]) }
      else held.eql?(value)
      end
    end

    # The state of the transaction running now, if any: the one a write belongs to, whose rollback
    # undoes it. Its state is marked rolled back with the outermost transaction's too.
    def current_transaction_state
      transaction = self.class.connection.current_transaction
      transaction.state if transaction.respond_to?(:state)
    end

    # The transaction that creates the record, whose rollback leaves it new again. The record's own state is
    # restored only after the rollback callbacks, so they tell a rolled-back creation apart by it.
    def remember_creating_transaction
      @creating_transaction_state = current_transaction_state
    end

    # Refill data_options and data_metas from the last write when the transaction that ran it is rolled
    # back, so the next save of this instance writes them; values queued since are kept, and a rollback
    # of a later transaction leaves the write, which stands, consumed. The metas of a record whose creation
    # is rolled back are built again whether or not it wrote any.
    def requeue_metas_options
      options, metas, state = @written_metas_options
      created = @creating_transaction_state&.rolledback?
      if state&.rolledback?
        @written_metas_options = nil
        self.data_options = options if data_options.blank?
        self.data_metas = metas if data_metas.blank?
      end
      return unless created || state&.rolledback?

      @creating_transaction_state = nil if created
      forget_rolled_back_metas(created)
    end

    # The rows the rolled-back transaction wrote are gone while the metas in memory still claim them.
    # A record whose creation was rolled back had every meta of its written there: they are built again,
    # so the next save stores them, and read, since the record is new again. A record that existed keeps
    # its earlier rows, so its metas are dropped and read again on demand. Either way what the instance
    # memoized is dropped: a record whose creation was rolled back takes back the id it had before the save,
    # under which the values it memoized then would be read over the metas it holds.
    def forget_rolled_back_metas(created)
      if created
        built = metas.target.map { |meta| { key: meta.key, value: meta.value } }
        metas.reset
        built.each { |attributes| metas.build(attributes) }
      else
        metas.reset
      end
      cama_clear_cache
    end

    def forget_written_metas_options
      @written_metas_options = nil
      @creating_transaction_state = nil
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

    # The row of key a read takes: the lowest id among the key's stored rows, from the metas in memory when they
    # are loaded or complete, as those of a record not saved yet always are, and from the database otherwise,
    # or, for a key with no stored row among the metas in memory, a meta built and not saved yet. With
    # stored_only, the stored row a write updates, leaving out a built meta, which a write sets in place.
    def meta_row(key_str, stored_only: false)
      if metas.loaded? || new_record? || created_record_metas_in_memory?
        rows = metas.target.select { |m| m.key == key_str }
        stored = rows.select(&:persisted?)
        (stored.empty? && !stored_only ? rows : stored).min_by { |m| m.id.to_i }
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
