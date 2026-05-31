module CamaleonCms
  module Frontend
    module SiteHelper
      # return full current visited url
      def site_current_url
        request.original_url
      end

      # return current url visited as path
      # http://localhost:9001/category/cat-post-2  => /category/cat-post-2
      def site_current_path
        CurrentRequest.frontend_site_current_path ||= site_current_url.sub(cama_root_url(locale: nil), '/')
      end

      # **************** section is a? ****************#
      # check if current section visited is home page
      def is_home?
        camaleon_frontend_visited_state(:frontend_visited_home).present?
      end

      # check if current section visited is for post
      def is_page?
        camaleon_frontend_visited_state(:frontend_visited_post).present?
      end

      # check if current section visited is for ajax
      def is_ajax?
        camaleon_frontend_visited_state(:frontend_visited_ajax).present?
      end

      # check if current section visited is for search
      def is_search?
        camaleon_frontend_visited_state(:frontend_visited_search).present?
      end

      # check if current section visited is for post type
      def is_post_type?
        camaleon_frontend_visited_state(:frontend_visited_post_type).present?
      end

      # check if current section visited is for post tag
      def is_post_tag?
        camaleon_frontend_visited_state(:frontend_visited_tag).present?
      end

      # check if current section visited is for category
      def is_category?
        camaleon_frontend_visited_state(:frontend_visited_category).present?
      end

      # check if visited page is user profile (frontend)
      def is_profile?
        camaleon_frontend_visited_state(:frontend_visited_profile) == true
      end

      # **************** end section is a? ****************#

      # show custom assets added by plugins
      # show respond js and html5shiv
      # seo_attrs: Custom attributes for seo in Hash format
      # show_seo: (Boolean) control to append or not the seo attributes
      def the_head(seo_attrs = {}, _show_seo = true)
        js = javascript_tag("var ROOT_URL = #{cama_root_url.to_json}; var LANGUAGE = #{I18n.locale.to_s.to_json};")
        safe_join(
          [
            csrf_meta_tag.presence,
            display_meta_tags(cama_the_seo(seo_attrs)).presence,
            js,
            cama_draw_pre_asset_contents.presence,
            cama_draw_custom_assets.presence
          ].compact,
          "\n"
        )
      end

      private

      def camaleon_frontend_visited_state(current_request_attr)
        CurrentRequest.public_send(current_request_attr)
      end
    end
  end
end
