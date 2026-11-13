module CamaleonCms
  module Admin
    module CustomFieldsHelper
      # The options and extra fields that several field types of cama_custom_field_elements share. Each
      # type gets a deep copy, so a change that an `extra_custom_fields` hook makes to one type reaches
      # no other type and no other request.
      VALUE_OPTIONS = { required: true, multiple: true, default_value: '', show_frontend: true }.freeze
      TRANSLATED_VALUE_OPTIONS = { required: true, multiple: true, translate: true, default_value: '',
                                   show_frontend: true }.freeze
      RECORD_OPTIONS = { required: true, multiple: true, show_frontend: true }.freeze
      REQUIRED_MULTIPLE_OPTIONS = { required: true, multiple: true }.freeze
      FORMATS_EXTRA_FIELDS = [{ type: 'text_box', key: 'formats', label: 'File Formats (image,video,audio)' }].freeze
      private_constant :VALUE_OPTIONS, :TRANSLATED_VALUE_OPTIONS, :RECORD_OPTIONS, :REQUIRED_MULTIPLE_OPTIONS,
                       :FORMATS_EXTRA_FIELDS

      def cama_custom_field_elements
        return CurrentRequest.custom_field_elements if CurrentRequest.custom_field_elements.present?

        fields = 'camaleon_cms.admin.custom_field.fields'
        items = {}
        items[:text_box] = cf_element('text_box', t("#{fields}.text_box"), TRANSLATED_VALUE_OPTIONS)
        items[:text_area] = cf_element('text_area', t("#{fields}.text_area"), TRANSLATED_VALUE_OPTIONS)
        items[:select] = cf_element('select', t("#{fields}.select"),
                                    { required: true, multiple: true, translate: true,
                                      multiple_options: { label: t('camaleon_cms.admin.settings.options_select'),
                                                          default: 'radio' },
                                      show_frontend: true })
        items[:radio] = cf_element('radio', t("#{fields}.radio", default: 'Radio'),
                                   { required: true, multiple: false,
                                     multiple_options: { label: t('camaleon_cms.admin.settings.options_select'),
                                                         default: 'radio', use_not_default: true },
                                     show_frontend: true })
        items[:checkbox] = cf_element('checkbox', t("#{fields}.checkbox", default: 'Checkbox'),
                                      { required: true, multiple: false, default_value: '1', show_frontend: true })
        items[:checkboxes] = cf_element('checkboxes', t("#{fields}.checkboxes", default: 'Checkboxes'),
                                        { required: false, multiple: false,
                                          multiple_options: { label: 'Checkboxes', default: 'checkbox' },
                                          show_frontend: true })
        items[:audio] = cf_element('audio', t("#{fields}.audio", default: 'Audio'), VALUE_OPTIONS)
        items[:colorpicker] = cf_element('colorpicker', t("#{fields}.colorpicker"), VALUE_OPTIONS,
                                         [{ type: 'select', key: 'color_format', label: 'Color Format',
                                            values: %w[hex rgb rgba].map do |format|
                                              { value: format, label: format }
                                            end }])
        items[:date] = cf_element('date', t("#{fields}.date"), VALUE_OPTIONS,
                                  [{ type: 'radio', key: 'type_date',
                                     values: [{ value: '0', label: t('camaleon_cms.admin.settings.input_only_date') },
                                              { value: '1',
                                                label: t('camaleon_cms.admin.settings.input_date_time') }] }])
        items[:editor] = cf_element('editor', t("#{fields}.editor", default: 'Editor'),
                                    { required: false, multiple: true, translate: true, default_value: '',
                                      show_frontend: true })
        items[:email] = cf_element('email', t("#{fields}.email"), VALUE_OPTIONS)
        items[:file] = cf_element('file', t("#{fields}.file"), VALUE_OPTIONS, FORMATS_EXTRA_FIELDS)
        items[:image] = cf_element('image', t("#{fields}.image"), VALUE_OPTIONS,
                                   [{ type: 'text_box', key: 'dimension',
                                      label: cama_t("#{fields}.image_dimension"),
                                      description: cama_t("#{fields}.image_dimension_descr") },
                                    { type: 'text_box', key: 'versions',
                                      label: cama_t("#{fields}.image_versions"),
                                      description: cama_t("#{fields}.image_versions_descr") }])
        items[:numeric] = cf_element('numeric', t("#{fields}.numeric"), VALUE_OPTIONS)
        items[:phone] = cf_element('phone', t("#{fields}.phone"), VALUE_OPTIONS)
        items[:url] = cf_element('url', t("#{fields}.url", default: 'URL'), TRANSLATED_VALUE_OPTIONS)
        items[:video] = cf_element('video', t("#{fields}.video", default: 'Video'), VALUE_OPTIONS)
        items[:users] = cf_element('users', t("#{fields}.users"), RECORD_OPTIONS)
        items[:posts] = cf_element('posts', t("#{fields}.posts"), RECORD_OPTIONS,
                                   [{ type: 'checkbox', key: 'post_types', label: 'Post types',
                                      values: current_site.post_types.pluck(:id, :name).map do |pt|
                                                { value: pt.first, label: pt.last }
                                              end.unshift({ value: 'all', label: '--- All Post Types ---' }) }])
        items[:post_types] = cf_element('post_types', t('camaleon_cms.admin.post_type.post_types'),
                                        REQUIRED_MULTIPLE_OPTIONS)
        items[:categories] =
          cf_element('categories', t('camaleon_cms.admin.table.categories'), REQUIRED_MULTIPLE_OPTIONS)
        # evaluate the content of command value on listing
        # sample command:
        # options_from_collection_for_select(current_site.the_posts("commerce").decorate, :id, :the_title)
        items[:select_eval] = cf_element('select_eval', t("#{fields}.select_eval"),
                                         { required: true, multiple: false, default_value: '', show_frontend: false },
                                         [{ type: 'text_area', key: 'command', label: 'Command to Eval' }])
        items[:field_attrs] = cf_element('field_attrs', t("#{fields}.field_attrs"),
                                         { required: false, multiple: true, show_frontend: true, translate: true })
        items[:private_file] = cf_element('private_file', t("#{fields}.private_file", default: 'Private File'),
                                          { required: true, multiple: true, default_value: '' }, FORMATS_EXTRA_FIELDS)
        r = { fields: items }
        hooks_run('extra_custom_fields', r)
        CurrentRequest.custom_field_elements = r[:fields]
      end

      # add your model class into custom fields editor
      # Note: to use custom fields on your model, you need the following:
      # - add: belongs_to :site (in your model)
      #   //don't forget multi site support, i.e.: you need site_id attribute in your table
      # - add: include CamaleonCms::CommonRelationships and include CamaleonCms::CustomFieldsRead (in your
      #   model). CommonRelationships gives the custom_field_values association.
      # - add: include CamaleonCms::Metas (in your model) to show the fields in an admin form. The
      #   custom_fields/render partial calls get_option, which Metas gives. Metas calls the cache methods
      #   of CamaleonRecord, so the model must also inherit from CamaleonRecord. The custom-field readers
      #   and writers need neither.
      # ==> With this, you can manage your model like a plugin. Check api -> custom fields section into docs)
      # model_class: class name (Product)
      def cf_add_model(model_class)
        CurrentRequest.extra_models_for_fields ||= []
        CurrentRequest.extra_models_for_fields << model_class
      end

      # Models offered in the field-group placement dropdown: those registered via cf_add_model plus any
      # a custom_field_custom_models hook appends. Seeded from the legacy @_extra_models_for_fields ivar
      # so a controller still assigning it keeps working. The dropdown used to read that ivar while
      # cf_add_model wrote CurrentRequest, so registered models never appeared. Regression M18.
      # The seed and the hook payload are copies: hook appends must reach only this read, not
      # accumulate in the request store or leak into the controller ivar.
      def cf_extra_models_for_fields
        CurrentRequest.extra_models_for_fields ||= (instance_variable_get(:@_extra_models_for_fields) || []).dup
        f_args = { models: CurrentRequest.extra_models_for_fields.dup }
        hooks_run('custom_field_custom_models', f_args)
        f_args[:models]
      end

      # The field values that the custom-fields partial shows for one field group of a record. A form
      # that renders again after a failed save shows the submitted values. A GET request shows the
      # values of the record, so a link cannot put values into the form. The helper reads the request
      # method itself, and no save action passes the values, because plugin forms render the partial
      # too.
      # record: the record of the form
      # slugs: the slugs of the fields of the group
      def cama_form_field_values(record, slugs)
        return record.get_fields_grouped(slugs) if request.get? || params[:field_options].blank?

        cama_submitted_field_values(params[:field_options])
      end

      # The values that a request submits for the field groups of a record, in the shape that
      # build_custom_field_group reads: one Hash per group, from the slug of a field to its values. The
      # custom-fields partial shows them again when an admin save renders its form again. A param that
      # is not a set of groups, a group that is not a set of fields and a field entry that is not a set
      # of attributes are left out. So a malformed param raises no 500, and the form shows only the
      # values of what is well formed.
      def cama_submitted_field_values(submitted)
        return [] unless submitted.is_a?(ActionController::Parameters)

        submitted.to_unsafe_h.values.filter_map do |group|
          next unless group.is_a?(Hash)

          group.each_with_object({}) do |(slug, entry), values|
            next unless entry.is_a?(Hash)

            submitted_values = entry['values']
            values[slug] = submitted_values.is_a?(Hash) ? submitted_values.values : submitted_values
          end
        end
      end

      private

      # One field type of the table: its key, its label for the custom-fields editor, a deep copy of its
      # options and, when it has them, its extra fields. It is private because it is no public API.
      # Private does not stop every call: the `h` proxy of a Draper decorator calls a helper with `send`.
      def cf_element(key, label, options, extra_fields = nil)
        { key: key, label: label, options: options.deep_dup, extra_fields: extra_fields.deep_dup }.compact
      end
    end
  end
end
