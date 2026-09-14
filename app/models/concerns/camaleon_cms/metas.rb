module CamaleonCms
  module Metas
    extend ActiveSupport::Concern

    # Raised by set_metas/set_options for a container that is present but not a set of fields (an
    # array of pairs, a scalar). The writers iterate a container key by key, so such input would be
    # stored pair by pair past every hash-shaped check, or raise deep inside on to_sym; it is refused
    # up front and nothing is written.
    class InvalidContainer < ArgumentError; end

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

    def self.indifferent_json_value(value)
      case value
      when Hash then value.with_indifferent_access
      when Array then value.map { |item| indifferent_json_value(item) }
      else value
      end
    end
    private_class_method :indifferent_json_value

    # Add meta with value or Update meta with key: key
    # return true or false
    def set_meta(key, value)
      fixed_value = fix_meta_value(value)

      # Check if the parent object has been saved to the database yet
      if persisted?
        # A meta built before the first save is still pending during the after_create callbacks, and the
        # metas autosave inserts it afterwards: update it instead of adding a second row for the key.
        # Otherwise update the lowest id when a key has several rows: the one get_meta reads.
        pending_record = metas.target.find { |m| m.new_record? && m.key == key.to_s }
        if pending_record
          pending_record.value = fixed_value
        elsif (meta_record = stored_meta_row(key.to_s))
          meta_record.update(value: fixed_value)
        else
          metas.create(key: key.to_s, value: fixed_value)
        end
      else
        # In-Memory Fallback: Find an existing unsaved item in the array collection,
        # or build a brand new unsaved record on the association.
        meta_record = metas.find { |m| m.key == key.to_s }

        if meta_record
          meta_record.value = fixed_value
        else
          metas.build(key: key.to_s, value: fixed_value)
        end
      end

      cama_set_cache("meta_#{key}", value)
    end

    # return value of meta with key: key,
    # if meta not exist, or its value == "", return default
    def get_meta(key, default = nil)
      key_str = key.is_a?(Symbol) ? key.to_s : key
      cama_fetch_cache("meta_#{key_str}") do
        option = if metas.loaded? || created_record_metas_in_memory?
                   metas.target.select { |m| m.key == key_str }.min_by { |m| m.id.to_i }
                 else
                   metas.where(key: key_str).first
                 end
        res = ''
        if option.present?
          value = begin
            # a key an older write stored twice keeps its last value, as json 2 read it
            JSON.parse(option.value, allow_duplicate_key: true)
          rescue StandardError
            option.value
          end
          res = begin
            (value.is_a?(Hash) ? value.with_indifferent_access : value)
          rescue StandardError
            option.value
          end
        end
        res == '' ? default : res
      end
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
    # A stored row that is not a JSON object (legacy or corrupt data) reads as no options, so every
    # reader and writer works on the record; the row is replaced the next time an option is written.
    def options(meta_key = '_default')
      stored = get_meta(meta_key, ActiveSupport::HashWithIndifferentAccess.new)
      stored.is_a?(Hash) ? stored : ActiveSupport::HashWithIndifferentAccess.new
    end
    alias cama_options options

    # add configuration for current object
    # key: attribute name
    # value: attribute value
    # meta_key: (String) name of the meta attribute
    # sample: mymodel.set_custom_option("my_settings", "color", "red")
    def set_option(key, value = nil, meta_key = '_default')
      return if key.nil?

      data = writable_options(meta_key)
      data[key] = fix_meta_var(value)
      set_meta(meta_key, data)
      value
    end

    # return configuration for current object
    # key: attribute name
    # default: if the attribute doesn't exist, or its value == "", return default
    # return value for attribute
    def get_option(key = nil, default = nil, meta_key = '_default')
      values = cama_options(meta_key)
      return default if key.nil?

      key = key.to_sym
      values.key?(key) && values[key] != '' ? values[key] : default
    end

    # delete attribute from configuration
    def delete_option(key, meta_key = '_default')
      return if key.nil?

      values = writable_options(meta_key)
      key = key.to_sym
      values.delete(key) if values.key?(key)
      set_meta(meta_key, values)
    end

    # set multiple configurations
    # h: {ket1: "sdsds", ff: "fdfdfdfd"}
    def set_options(h = {}, meta_key = '_default')
      return if h.blank?

      refuse_invalid_container!(h)
      data = writable_options(meta_key)
      PluginRoutes.fixActionParameter(h).to_sym.each do |key, value|
        data[key] = fix_meta_var(value)
      end
      set_meta(meta_key, data)
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

    # The stored row a write updates: the lowest id among the key's rows, taken from the metas in
    # memory when they are loaded or complete, and from the database otherwise, as get_meta takes the
    # row it reads.
    def stored_meta_row(key_str)
      if metas.loaded? || created_record_metas_in_memory?
        metas.target.select { |m| m.persisted? && m.key == key_str }.min_by { |m| m.id.to_i }
      else
        metas.where(key: key_str).order(:id).first
      end
    end

    def created_record_metas_in_memory?
      @created_record_metas_in_memory == true
    end

    # the options hash the option writers update: indifferent, as a stored one is parsed, so a String
    # key replaces its Symbol twin instead of being stored beside it
    def writable_options(meta_key)
      data = cama_options(meta_key)
      data.is_a?(ActiveSupport::HashWithIndifferentAccess) ? data : data.with_indifferent_access
    end

    # fix to parse value
    def fix_meta_value(value)
      changed_value = if value.is_a?(ActionController::Parameters)
                        value.to_json
                      elsif value.is_a?(Array) || value.is_a?(Hash)
                        CamaleonCms::Metas.generate_json(value)
                      else
                        value
                      end
      fix_meta_var(changed_value)
    end

    # fix to detect type of the variable
    def fix_meta_var(value)
      value = value.to_var if value.is_a?(String)
      value
    end
  end
end
