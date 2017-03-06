#encoding: utf-8
module CamaleonCms::Admin::CustomFieldsHelper
  def cama_custom_field_elements
    return @_cama_custom_field_elements if @_cama_custom_field_elements.present?
    items = {}
    items[:text_box] = {
        key: 'text_box',
        label: t('camaleon_cms.admin.custom_field.fields.text_box'),
        options: {
            required: true,
            multiple: true,
            translate: true,
            default_value: '',
            show_frontend: true
        }
    }

    items[:text_area] = {
        key: 'text_area',
        label: t('camaleon_cms.admin.custom_field.fields.text_area'),
        options: {
            required: true,
            multiple: true,
            translate: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:select] = {
        key: 'select',
        label: t('camaleon_cms.admin.custom_field.fields.select'),
        options: {
            required: true,
            multiple: true,
            translate: true,
            multiple_options: {
                label: t('camaleon_cms.admin.settings.options_select'),
                default: 'radio'
            },
            show_frontend: true
        }
    }
    items[:radio] = {
        key: 'radio',
        label: 'Radio',
        options: {
            required: true,
            multiple: false,
            multiple_options: {
                label: t('camaleon_cms.admin.settings.options_select'),
                default: 'radio',
                use_not_default: true
            },
            show_frontend: true
        }
    }

    items[:checkbox] = {
        key: 'checkbox',
        label: 'Checkbox',
        options: {
            required: true,
            multiple: false,
            default_value: '1',
            show_frontend: true
        }
    }
    items[:checkboxes] = {
        key: 'checkboxes',
        label: 'Checkboxes',
        options: {
            required: false,
            multiple: false,
            multiple_options: {
                label: 'Checkboxes',
                default: 'checkbox'
            },
            show_frontend: true
        }
    }
    items[:audio] = {
        key: 'audio',
        label: 'Audio',
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:colorpicker] = {
        key: 'colorpicker',
        label: t('camaleon_cms.admin.custom_field.fields.colorpicker'),
        extra_fields:[
            {
                type: 'select',
                key: 'color_format',
                label: 'Color Format',
                values: [
                    {
                        value: 'hex',
                        label: 'hex'
                    },
                    {
                        value: 'rgb',
                        label: 'rgb'
                    },
                    {
                        value: 'rgba',
                        label: 'rgba'
                    }
                ]
            }
        ],
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:date] = {
        key: 'date',
        label: t('camaleon_cms.admin.custom_field.fields.date'),
        extra_fields:[
            {
                type: 'radio',
                key: 'type_date',
                values: [
                    {
                        value: '0',
                        label: t('camaleon_cms.admin.settings.input_only_date')
                    },
                    {
                        value: '1',
                        label: t('camaleon_cms.admin.settings.input_date_time')
                    }
                ]
            }
        ],
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:editor] = {
        key: 'editor',
        label: 'Editor',
        options: {
            required: false,
            multiple: true,
            translate: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:email] = {
        key: 'email',
        label: t('camaleon_cms.admin.custom_field.fields.email'),
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:file] = {
        key: 'file',
        label: t('camaleon_cms.admin.custom_field.fields.file'),
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true,
        },
        extra_fields:[
            {
                type: 'text_box',
                key: 'formats',
                label: 'File Formats (image,video,audio)'
            }
        ]
    }
    items[:image] = {
        key: 'image',
        label: t('camaleon_cms.admin.custom_field.fields.image'),
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        },
        extra_fields:[
            {
                type: 'text_box',
                key: 'dimension',
                label: cama_t('camaleon_cms.admin.custom_field.fields.image_dimension'),
                description: cama_t('camaleon_cms.admin.custom_field.fields.image_dimension_descr'),
            },
            {
                type: 'text_box',
                key: 'versions',
                label: cama_t('camaleon_cms.admin.custom_field.fields.image_versions'),
                description: cama_t('camaleon_cms.admin.custom_field.fields.image_versions_descr')
            }
        ]
    }
    items[:numeric] = {
        key: 'numeric',
        label: t('camaleon_cms.admin.custom_field.fields.numeric'),
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:phone] = {
        key: 'phone',
        label: t('camaleon_cms.admin.custom_field.fields.phone'),
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:url] = {
        key: 'url',
        label: 'URL',
        options: {
            required: true,
            multiple: true,
            translate: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:video] = {
        key: 'video',
        label: 'Video',
        options: {
            required: true,
            multiple: true,
            default_value: '',
            show_frontend: true
        }
    }
    items[:users] = {
        key: 'users',
        label: t('camaleon_cms.admin.custom_field.fields.users'),
        options: {
            required: true,
            multiple: true,
            show_frontend: true
        }
    }
    items[:posts] = {
        key: 'posts',
        label: t('camaleon_cms.admin.custom_field.fields.posts'),
        options: {
            required: true,
            multiple: true,
            show_frontend: true
        },
        extra_fields:[
            {
                type: 'checkbox',
                key: 'post_types',
                label: 'Post types',
                values: current_site.post_types.pluck(:id, :name).map{|pt| {value: pt.first, label: pt.last}}.unshift({value: "all", label: "--- All Post Types ---"})
            }
        ]
    }

    items[:post_types] = {
        key: 'post_types',
        label: t('camaleon_cms.admin.post_type.post_types'),
        options: {
            required: true,
            multiple: true
        }
    }

    items[:categories] = {
        key: 'categories',
        label: t('camaleon_cms.admin.table.categories'),
        options: {
            required: true,
            multiple: true
        }
    }
    
    # evaluate the content of command value on listing
    # sample command: options_from_collection_for_select(current_site.the_posts("commerce").decorate, :id, :the_title)
    items[:select_eval] = {
        key: 'select_eval',
        label: t('camaleon_cms.admin.custom_field.fields.select_eval'),
        options: {
            required: true,
            multiple: false,
            default_value: '',
            show_frontend: false
        },
        extra_fields:[
            {
                type: 'text_area',
                key: 'command',
                label: 'Command to Eval'
            }
        ]
    }
    items[:field_attrs] = {
        key: 'field_attrs',
        label: t('camaleon_cms.admin.custom_field.fields.field_attrs'),
        options: {
            required: false,
            multiple: true,
            show_frontend: true,
            translate: true
        }
    }
    items[:private_file] = {
        key: 'private_file',
        label: t('camaleon_cms.admin.custom_field.fields.private_file', default: 'Private File'),
        options: {
            required: true,
            multiple: true,
            default_value: ''
        },
        extra_fields:[
            {
                type: 'text_box',
                key: 'formats',
                label: 'File Formats (image,video,audio)'
            }
        ]
    }
    r = {fields: items}; hooks_run("extra_custom_fields", r)
    @_cama_custom_field_elements = r[:fields]
  end

  # add your model class into custom fields editor
  # Note: to use custom fields on your model, you need the following:
  # - add: belongs_to :site (in your model) //don't forget multi site support, i.e.: you need site_id attribute in your table
  # - add: include CamaleonCms::CustomFieldsRead (in your model)
  # ==> With this, you can manage your model like a plugin. Check api -> custom fields section into docs)
  # model_class: class name (Product)
  def cf_add_model(model_class)
    @_extra_models_for_fields << model_class
  end
end
