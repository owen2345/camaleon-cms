module Themes::CamaleonCms::MainHelper
  def self.included(klass)
    klass.helper_method [:camaleon_cms_draw_links] rescue ""
  end

  def camaleon_cms_settings(theme)
    # here your code on save settings for current site
  end

  def camaleon_cms_on_install_theme(theme)
    current_site.nav_menus.create(name: "Camaleon left menu", slug: "left_main_menu", description: "Use #banner #features #expertise #team #counters #gallery #testimonial #pricing #clients #blog #contact #normal as links in home page.") unless current_site.nav_menus.where(slug: "left_main_menu").present?
    current_site.nav_menus.create(name: "Camaleon right menu", slug: "right_main_menu", description: "Use #banner #features #expertise #team #counters #gallery #testimonial #pricing #clients #blog #contact #normal as links in home page.") unless current_site.nav_menus.where(slug: "right_main_menu").present?

    ids = []
    # layout
    pt0 = current_site.post_types.create(name: "Layout", slug: "camaleon_layout")
    pt0.set_settings({has_summary: false, has_picture: false })
    pt0.add_field({name: "Sub title", slug: "sub_title"}, {field_key: "text_box", translate: true})
    pt0.add_field({name: "Layout", slug: "layout"}, {field_key: "select", multiple_options: [
                                                                        {title: "Banner", value: "banner", default: true},
                                                                        {title: "Features", value: "features"},
                                                                        {title: "Expertise", value: "expertise"},
                                                                        {title: "Team", value: "team"},
                                                                        {title: "Counters", value: "counters"},
                                                                        {title: "Gallery", value: "gallery"},
                                                                        {title: "Testimonials", value: "testimonials"},
                                                                        {title: "Pricing", value: "pricing"},
                                                                        {title: "Clients", value: "clients"},
                                                                        {title: "News (blog)", value: "blog"},
                                                                        {title: "Contact", value: "contact"},
                                                                        {title: "Normal", value: "normal"}
                                                                    ]})
    pt0.add_field({name: "Background Image", slug: "bg", description: "Size (1900px x 900px). Not support for: Banner."}, {field_key: "image"})
    pt0.add_field({name: "Background color", slug: "bg_color", description: "Not support for: Banner."}, {field_key: "colorpicker", color_format: "rgba"})
    ids << pt0.id

    # slider
    pt1 = current_site.post_types.create(name: "Home Slider", slug: "camaleon_slider")
    pt1.set_settings({has_picture: false, has_summary: false, has_keywords: false })
    pt1.add_field({name: "Background image", slug: "bg", description: "Size (1520px x 750px)"}, {field_key: "image", required:true})
    pt1.add_field({name: "Shadow Color", slug: "color"}, {field_key: "checkbox"})
    ids << pt1.id

    # features
    pt_we_are = current_site.post_types.create(name: "Features", slug: "camaleon_features")
    pt_we_are.set_settings({has_picture: true })
    pt_we_are.add_field({name: "Icon", slug: "icon", description: "Use an icon from font awesome"}, {field_key: "text_box", default_value: "fa-dashboard", required:true})
    # pt_we_are.add_field({name: "Shadow Color", slug: "color"}, {field_key: "checkbox"})
    ids << pt_we_are.id

    # expertise
    pt2 = current_site.post_types.create(name: "Expertise", slug: "camaleon_expertise")
    pt2.set_settings({has_summary: false, has_picture: true })
    pt2.add_field({name: "Percentage", slug: "percentage"}, {field_key: "numeric", required:true})
    # pt2.add_field({name: "Shadow Color", slug: "color"}, {field_key: "checkbox"})
    ids << pt2.id

    # team
    pt3 = current_site.post_types.create(name: "Team", slug: "camaleon_team")
    pt3.set_settings({has_picture: false, has_content: false})
    pt3.add_field({name: "Photo", slug: "photo", description: "Resolution 150px x 150px"}, {field_key: "image", required:true})
    pt3.add_field({name: "Role", slug: "role"}, {field_key: "text_box", required:true})
    gr_team = pt3.add_field_group({name: "Social", slug: "social"})
    gr_team.add_field({name: "Facebook", slug: "fb"}, {field_key: "url"})
    gr_team.add_field({name: "Twitter", slug: "tw"}, {field_key: "url"})
    gr_team.add_field({name: "Linkedin", slug: "lk"}, {field_key: "url"})
    ids << pt3.id

    # counters
    pt4 = current_site.post_types.create(name: "Counters", slug: "camaleon_counters")
    pt4.set_settings({has_summary: false, has_picture: false })
    pt4.add_field({name: "Number count", slug: "count"}, {field_key: "numeric", required:true})
    ids << pt4.id

    # gallery
    pt_gallery = current_site.post_types.create(name: "Gallery", slug: "camaleon_gallery")
    pt_gallery.set_settings({has_content: false, has_summary: false, has_picture: false, has_category: true, has_keywords: false })
    pt_gallery.categories.create({name: 'Photos', slug: 'photos'})
    pt_gallery.categories.create({name: 'Videos', slug: 'videos'})
    pt_gallery.add_field({name: "Thumbnail", slug: "thumb", description: "Size (390px x 315px)"}, {field_key: "image", required:true})
    pt_gallery.add_field({name: "Gallery File (image or video)", slug: "file"}, {field_key: "file", required:true, formats: "video,audio,image"})
    ids << pt_gallery.id

    # testimonials
    pt_test = current_site.post_types.create(name: "Testimonials", slug: "camaleon_testimonial")
    pt_test.set_settings({has_summary: false, has_picture: false})
    ids << pt_test.id

    # pricing
    pt_pricing = current_site.post_types.create(name: "Pricing", slug: "camaleon_pricing")
    pt_pricing.set_settings({has_summary: false, has_picture: true })
    pt_pricing.add_field({name: "Price title", slug: "price"}, {field_key: "text_box", required:true, translate: true})
    pt_pricing.add_field({name: "Details", slug: "details"}, {field_key: "text_box", required:true, translate: true, multiple: true})
    pt_pricing.add_field({name: "Button Label", slug: "btn_label"}, {field_key: "text_box", required:true, translate: true, default_value: "Sign Up Now"})
    ids << pt_pricing.id

    # clients
    pt_client = current_site.post_types.create(name: "Clients", slug: "camaleon_clients")
    pt_client.set_settings({has_summary: false, has_picture: false})
    pt_client.add_field({name: "Logo", slug: "logo", description: "Size (120px x 50px)"}, {field_key: "image", required:true})
    ids << pt_client.id

    # settings
    theme.add_field({name: "Theme Color", slug: "theme"}, {field_key: "select", multiple_options: [
        {title: "Orange", value: "orange", default: true},
        {title: "Red", value: "red"},
        {title: "Blue", value: "blue"},
        {title: "Green", value: "green"},
        {title: "Yellow", value: "yellow"}
    ]})
    theme.add_field({"name"=>"Internal pages background image", "slug"=>"inner_bg", description: "Size (1600px x 260px)"},{field_key: "image" })
    theme.add_field({"name"=>"Google Analytics", "slug"=>"analytics", description: "Enter your google analytics code."},{field_key: "text_area", translate: true })

    # theme.add_field({"name"=>"Home Contact form", "slug"=>"home_contact", description: "Past the shortcode of your contact form"},{field_key: "text_box", translate: true})
    theme.add_field({"name"=>"Footer description", "slug"=>"footer_descr"},{field_key: "editor", translate: true})
    theme.save_field_value("footer_descr", "Copyright &copy; 2015 Camaleon. All rights reserved.")

    # social
    gr = theme.add_field_group({name: "Social links", slug: "social"})
    gr.add_field({"name"=>"Title", "slug"=>"social_label"},{field_key: "text_box", translate: true, }); theme.save_field_value("social_label", "Connect with us")
    gr.add_field({"name"=>"Facebook Url", "slug"=>"fb_url"},{field_key: "url"})
    gr.add_field({"name"=>"Twitter Url", "slug"=>"tw_url"},{field_key: "url"})
    gr.add_field({"name"=>"Google Url", "slug"=>"gl_url"},{field_key: "url"})
    gr.add_field({"name"=>"Instagram Url", "slug"=>"in_url"},{field_key: "url"})
    gr.add_field({"name"=>"Youtube Url", "slug"=>"yt_url"},{field_key: "url"})
    gr.add_field({"name"=>"Linkedin Url", "slug"=>"lk_url"},{field_key: "url"})
    gr.add_field({"name"=>"Github Url", "slug"=>"gt_url"},{field_key: "url"})

    theme.set_meta("pt_created", ids)
  end

  def camaleon_cms_on_uninstall_theme(theme)
    current_site.post_types.where(id: theme.get_meta("pt_created")).destroy_all
    current_site.nav_menus.where(slug: ["left_main_menu", "right_main_menu"]).destroy_all
    theme.destroy
  end

  def camaleon_cms_draw_links
    res = []
    if (l = current_theme.get_field("fb_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-facebook"></i></a>'
    end
    if (l = current_theme.get_field("tw_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-twitter"></i></a>'
    end
    if (l = current_theme.get_field("gl_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-google-plus"></i></a>'
    end
    if (l = current_theme.get_field("in_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-instagram"></i></a>'
    end
    if (l = current_theme.get_field("yt_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-youtube"></i></a>'
    end
    if (l = current_theme.get_field("lk_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-linkedin"></i></a>'
    end
    if (l = current_theme.get_field("gt_url")).present?
      res << '<a href="'+l+'" class="fb animate bounceIn" data-delay="1400"><i class="fa fa-github"></i></a>'
    end
    res.join("")
  end

  #{field: ob, form: form, template: temp }
  def camaleon_cms_contact(args)
    args[:template] = "[ci]"
    args[:custom_class] += " animate bounceIn "
    args[:custom_attrs]["data-delay"] = "500"
    args[:custom_attrs]["placeholder"] = args[:field][:label]
  end

  def camaleon_cms_contact_render(args)
    args[:submit] = "<label><span>&nbsp;</span>
                          <button class='submit_btn animate swing' data-delay='1000' id='submit_btn'>[submit_label]</button>
                      </label>"
    args[:before_form] = "<div class='contact'> <div class='form form3 animate bounceInUp'>  <fieldset id='contact_form'>"
    args[:after_form] = "</fieldset> </div> </div>"
  end

  def camaleon_cms_front_before()
    breadcrumb_add("<i class='fa fa-home'></i>", root_url)
    shortcode_add("bootstrap_slider", "partials/bootstrap_slider")
    shortcode_add("redirect", "partials/redirect")
  end
end