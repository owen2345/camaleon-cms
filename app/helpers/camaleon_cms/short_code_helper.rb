module CamaleonCms
  module ShortCodeHelper
    # Internal method
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
      # rubocop:disable Layout/LineLength
      shortcode_add(
        'asset',
        lambda do |attrs, args|
          return args[:shortcode] if attrs.blank?

          url = ActionController::Base.helpers.asset_url(attrs['file'])
          if attrs['image'].present?
            ActionController::Base.helpers.image_tag(attrs['file'], class: attrs['class'], style: attrs['style'])
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
    # rubocop:enable Layout/LineLength

    # add shortcode
    # key: shortcode key
    # template: template to render, if nil renders "shortcode_templates/<key>"
    # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content" }
    # descr: description for shortcode
    def shortcode_add(key, template = nil, descr = '')
      shortcode_keys << key
      CurrentRequest.shortcodes_template = shortcode_templates.merge({ key.to_s => template }) if template.present?
      shortcode_descriptions[key] = descr if descr.present?
    end

    # add or update shortcode template
    # key: chortcode key to add or update
    # template: template to render, if nil will render "shortcode_templates/<key>"
    def shortcode_change_template(key, template = nil)
      shortcode_templates[key] = template
    end

    # Delete the shortcode
    # key: chortcode key to delete
    def shortcode_delete(key)
      shortcode_keys.delete(key)
    end

    # run all shortcodes in the content
    # content: (string) text to find a short codes
    # args: custom arguments to pass for short codes render, sample: {owner: my_model, a: true}
    #   if args != Hash, this will re send as args = {owner: args}
    #   args should be include the owner model who is doing the action to optimize DB queries
    # sample: do_shortcode("hello [greeting 'world']!", @my_post) ==> "hello world!"
    # sample: do_shortcode("hello [greeting 'world']", {attr1: 'asd', owner: @my_post})
    # return rendered string
    def do_shortcode(content, args = {})
      args = { owner: args } unless args.is_a?(Hash)
      content.scan(/#{cama_reg_shortcode}/) do |item|
        content = _cama_replace_shortcode(content, item, args)
      end
      content
    end

    # remove all shortcodes from text
    # Arguments
    #   text: String that contains shortcodes
    # return String
    def cama_strip_shortcodes(text)
      text.gsub(/#{cama_reg_shortcode}/, '')
    end

    # render direct a shortcode
    # text: text that contain the shortcode
    # key: shortcode key
    # template: template to render, if nil this will render default render file
    # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content" }
    # render_shortcode(
    #   "asda dasdasdas[owen a='1'] [bbb] sdasdas dasd as das[owen a=213]", "owen",
    #   lambda { |attrs, args| puts attrs; return "my test"; }
    # )
    def render_shortcode(text, key, template = nil)
      text.scan(/#{cama_reg_shortcode(key)}/).each do |item|
        text = _cama_replace_shortcode(text, item, {}, template)
      end
      text
    end

    def shortcodes_list
      shortcode_keys
    end

    def shortcodes_descriptions
      shortcode_descriptions
    end

    private

    # helper to replace shortcodes adding support for closed shortcodes, sample: [title]my title[/title]
    def _cama_replace_shortcode(content, item, args = {}, template = nil)
      shortcode, code, attrs = item
      close_code = "[/#{code}]"
      if content.include?(close_code)
        shortcode_bk = shortcode
        tmp_content = content[content.index(shortcode)..]
        shortcode = tmp_content[0..(tmp_content.index(close_code) + close_code.size - 1)]
        args[:shortcode_content] = shortcode.sub(shortcode_bk, '').sub(close_code, '')
      end
      args[:shortcode] = shortcode
      args[:code] = code
      content.sub(shortcode, _eval_shortcode(code, attrs, args, template))
    end

    # create the regexpression for shortcodes
    # codes: (String) shortcode keys separated by |
    # sample: load_libraries|asset
    # if empty, codes will be replaced with all registered shortcodes
    # Return: (String) reg expression string
    def cama_reg_shortcode(codes = nil)
      # doesn't support for similar names, like: [media] and [media_gallery]
      # "(\\[(#{codes || (@_shortcodes || []).join("|")})(\s|\\]){0}(.*?)\\])"
      "(\\[(#{codes || shortcode_keys.join('|')})((\s)((?!\\]).)*|)\\])"
    end

    # determine the content to replace instead the shortcode
    # return string
    def _eval_shortcode(code, attrs, args = {}, template = nil)
      templates = shortcode_templates
      template ||= templates[code].presence || "camaleon_cms/shortcode_templates/#{code}"
      if templates[code].instance_of?(::Proc)
        templates[code].call(_shortcode_parse_attr(attrs), args)
      else
        render template: template, locals: { attributes: _shortcode_parse_attr(attrs), args: args }, formats: [:html]
      end
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

    # parse the attributes of a shortcode
    def _shortcode_parse_attr(text)
      res = {}
      return res if text.blank?

      # StringScanner tokenizes the text by moving through it sequentially,
      # matching patterns and advancing the scan pointer with each successful scan.
      scanner = StringScanner.new(text)

      # Continue parsing until we reach the end of the string.
      until scanner.eos?
        # Skip any leading whitespace before attempting to match a token.
        scanner.skip(/\s+/)
        break if scanner.eos?

        # Attempt to match a key=value attribute (e.g., width="100", class='foo', height=200).
        # Capture group 1 extracts the attribute name (word characters before =).
        if scanner.scan(/(\w+)\s*=\s*/)
          key = scanner[1]

          # Determine the attribute value based on its quoting style:
          # 1. Double-quoted string: "value" → extract content between quotes
          # 2. Single-quoted string: 'value' → extract content between quotes
          # 3. Unquoted value: any characters except whitespace or quotes
          val = if scanner.scan(/"([^"]*)"/)
                  scanner[1]
                elsif scanner.scan(/'([^']*)'/)
                  scanner[1]
                elsif scanner.scan(/([^\s'"]+)/)
                  scanner[1]
                end

          # Store the parsed key-value pair in the result hash.
          res[key] = val

        # If no key=value pattern matched, this is a standalone value (no assignment).
        # Match either a double-quoted string or a bare unquoted token.
        elsif scanner.scan(/"([^"]*)"|(\S+)/)
          # Use the appropriate capture group: group 1 for quoted, group 2 for unquoted.
          val = scanner[1] || scanner[2]
          # Standalone values are stored with a nil key reference.
          res[val] = nil
        end
      end
      res
    end

    # execute shortcode data
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

      if attrs['field'].present? # model custom fields
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

      else # model attributes
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

    # return the model object according to the type
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
        model = current_site.nav_menu_items.find_by(slug: attrs['key']) if attrs['key'].present?

      when 'user'
        model = current_site.the_user(attrs['id'].to_i) if attrs['id'].present?
        model = current_site.the_user(attrs['key'].to_s) if attrs['key'].present?
      end
      model
    end
  end
end
