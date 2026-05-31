# rubocop:disable Layout/LineLength
module CamaleonCms
  module RuntimeShortcodeThemeConcern
    extend ActiveSupport::Concern

    # Theme asset/view helpers are owned by CamaleonCms::ThemeHelper (single
    # source of truth shared with views). Including it here exposes them on the
    # controller runtime stack so plugin/theme hooks executed in controller
    # context (e.g. `on_install_theme`) can call `theme_asset`, `theme_view`,
    # `theme_asset_path`, etc. ThemeHelper is ivar-free, so it is safe to mix in.
    include CamaleonCms::ThemeHelper

    def shortcodes_init
      CurrentRequest.shortcodes = []
      CurrentRequest.shortcodes_template = {}
      CurrentRequest.shortcodes_descr = {}

      shortcode_add('widget', nil, "Renderize the widget content in this place.
                Don't forget to create and copy the shortcode of your widgets in appearance -> widgets
                Sample: [widget widget_key]")

      shortcode_add(
        'load_libraries',
        lambda do |attrs, args|
          return args[:shortcode] if attrs.blank?

          cama_load_libraries(*attrs['data'].to_s.split(','))
          ''
        end,
        "Permit to load libraries on demand, sample: [load_libraries data='datepicker,tinymce']"
      )
      shortcode_add(
        'asset',
        lambda do |attrs, args|
          return args[:shortcode] if attrs.blank?

          url = shortcode_asset_reference(attrs['file'], as_path: attrs['as_path'].present?)
          if attrs['image'].present?
            ActionController::Base.helpers.image_tag(url, class: attrs['class'], style: attrs['style'])
          else
            url
          end
        end,
        "Permit to generate an asset url (
        add file='' asset file path,
        add as_path='true' to generate only the path and not the full url,
        add class='my_class' to setup image class,
        add style='height: 100px; width: 200px;...' to setup image style,
        add image='true' to generate the image tag with this url),
      sample: <img src=\"[asset as_path='true' file='themes/my_theme/assets/img/signature.png']\" /> or [asset image='true' file='themes/my_theme/assets/img/signature.png' style='height: 50px;']"
      )

      shortcode_add(
        'data',
        ->(attrs, args) { attrs.present? ? cama_shortcode_data(attrs, args) : args[:shortcode] },
        "Permit to generate specific data of a post.
        Attributes:
          object: (String, defaut post) Model name: post | posttype | category | posttag | site | user |theme | navmenu
          id: (Integer) Post id
          key: (String) Post slug
          field: (String) Custom field key, you can add render_field='true' to render field as html element, also you can add index=2 to indicate the value in position 2 for multitple values
          attrs: (String) attribute name
                  post: title | created_at | excerpt | url | link | thumb | updated_at | author_name | author_url | content
                  posttype: title | created_at | excerpt | url | link | thumb | updated_at
                  category: title | created_at | excerpt | url | link | thumb | updated_at
                  posttag: title | created_at | excerpt | url | link | thumb | updated_at
                  site: title | created_at | excerpt | url | link | thumb | updated_at
                  user: title | created_at | excerpt | url | link | thumb | updated_at
                  theme: title | created_at | excerpt | url | link | thumb | updated_at
                  navmenu: title | created_at | excerpt | url | link | thumb | updated_at
          Note: If id and key is not present, then will be rendered for current model
        Sample:
          [data id='122' attr='title'] ==> return the title of post with id = 122
          [data key='contact' attr='url'] ==> return the url of post with slug = contact
          [data key='contact' attr='link'] ==> return the link with title as text of the link of post with slug = contact
          [data object='site' attr='url'] ==> return the url of currrent site
          [data key='page' object='posttype' attr='url'] ==> return the url of post_type with slug = page
          [data field=icon index=2] ==> return the second value (multiple values) for this custom field with key=icon of current object
          [data key='contact' field='sub_title'] ==> return the value of the custom_field with key=sub_title registered for post.slug = contact
          [data object='site' field='sub_title'] ==> return the value of the custom_field with key=sub_title registered for current_site"
      )
    end

    def shortcode_add(key, template = nil, descr = '')
      shortcode_keys << key
      CurrentRequest.shortcodes_template = shortcode_templates.merge({ key.to_s => template }) if template.present?
      shortcode_descriptions[key] = descr if descr.present?
    end

    def shortcode_keys
      CurrentRequest.shortcodes ||= []
    end

    def shortcode_templates
      CurrentRequest.shortcodes_template ||= {}
    end

    def shortcode_descriptions
      CurrentRequest.shortcodes_descr ||= {}
    end

    def shortcode_asset_reference(file, as_path: false)
      return if file.blank?

      file = resolve_shortcode_theme_asset(file)
      helper = ActionController::Base.helpers
      method_name = as_path ? :asset_path : :asset_url
      helper.public_send(method_name, file)
    rescue Sprockets::Rails::Helper::AssetNotFound
      helper.public_send(method_name, file, skip_pipeline: true)
    end

    def resolve_shortcode_theme_asset(file)
      match = file.to_s.match(%r{\Athemes/[^/]+/assets/(?<asset>.+)\z})
      return file unless match

      can_resolve_theme_assets = respond_to?(:current_theme) &&
                                 respond_to?(:theme_asset_path) &&
                                 respond_to?(:theme_asset_file_path)
      return file unless can_resolve_theme_assets
      return file if current_theme.blank?

      asset = match[:asset]
      remapped_file = theme_asset_path(asset)
      return file unless remapped_file.present? && remapped_file != file
      return file unless File.exist?(theme_asset_file_path(asset))

      remapped_file
    end

    def cama_shortcode_data(attrs, args)
      res = args[:shortcode]
      object = (attrs['object'].presence || 'post').downcase
      attr = attrs['attr'] || 'title'
      model = if attrs['id'].present? || attrs['key'].present?
                cama_shortcode_model_parser(object, attrs)
              else
                args[:owner]
              end
      return res if model.blank?

      if attrs['field'].present?
        field = model.get_field_object(attrs['field'])
        if attrs['render_field'].present?
          return render_to_string(template: "custom_fields/#{field.options['field_key']}", layout: false,
                                  locals: { object: model, field: field, field_key: attrs['field'], attibutes: attrs })
        end

        res = if attrs['index']
                begin
                  model.the_fields(attrs['field'])[attrs['index'].to_i - 1]
                rescue StandardError
                  ''
                end
              else
                model.the_field(attrs['field'])
              end
        return res
      else
        case attr
        when 'title'
          res = model.the_title
        when 'created_at'
          res = model.the_created_at
        when 'updated_at'
          res = model.the_updated_at
        when 'excerpt'
          res = begin
            model.the_excerpt
          rescue StandardError
            ''
          end
        when 'url'
          res = begin
            model.the_url
          rescue StandardError
            ''
          end
        when 'link'
          res = begin
            model.the_link
          rescue StandardError
            ''
          end
        when 'thumb'
          res = case object
                when 'site'
                  model.the_logo
                when 'user'
                  model.the_avatar
                else
                  model.the_thumb_url
                end
        else
          case object
          when 'post'
            case attr
            when 'content'
              res = model.try(:the_content)
            when 'author_name'
              res = model.try(:the_author).try(:the_name)
            when 'author_url'
              res = model.try(:the_author).try(:the_name)
            end
          end
        end
      end
      res
    end

    def cama_shortcode_model_parser(object, attrs)
      model = nil
      case object.downcase
      when 'post'
        model = current_site.the_post(attrs['id'].to_i) if attrs['id'].present?
        model = current_site.the_post(attrs['key'].to_s) if attrs['key'].present?
      when 'posttype'
        model = current_site.the_post_type(attrs['id'].to_i) if attrs['id'].present?
        model = current_site.the_post_type(attrs['key'].to_s) if attrs['key'].present?
      when 'category'
        model = current_site.the_category(attrs['id'].to_i) if attrs['id'].present?
        model = current_site.the_category(attrs['key'].to_s) if attrs['key'].present?
      when 'posttag'
        model = current_site.the_tag(attrs['id'].to_i) if attrs['id'].present?
        model = current_site.the_tag(attrs['key'].to_s) if attrs['key'].present?
      when 'site'
        model = current_site
      when 'theme'
        model = current_theme
      when 'navmenu'
        model = current_site.nav_menu_items.find(attrs['id']) if attrs['id'].present?
        model = current_site.nav_menu_items.find_by_slug(attrs['key']) if attrs['key'].present? # rubocop:disable Rails/DynamicFindBy
      when 'user'
        model = current_site.the_user(attrs['id'].to_i) if attrs['id'].present?
        model = current_site.the_user(attrs['key'].to_s) if attrs['key'].present?
      end
      model
    end
  end
end
# rubocop:enable Layout/LineLength
