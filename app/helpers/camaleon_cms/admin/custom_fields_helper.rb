=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
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
            multiple: false,
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
                label: 'Dimensions',
                description: 'Crop images with dimension (widthxheight), sample:<br>400x300 | 400x | x300 | ?400x?500 | ?1400x (? => maximum, empty => auto)'
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
    # evaluate the content of command value on listing
    # sample: get_select_options({})
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