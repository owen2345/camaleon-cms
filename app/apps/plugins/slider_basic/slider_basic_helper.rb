module Plugins::SliderBasic::SliderBasicHelper

  def slider_basic_on_import(args)
    plugins = args[:data][:plugins]
    if plugins[:slider_basics]
      plugins[:slider_basics].each do |sba|
        unless current_site.slider_basics.where(slug: sba[:slug]).first.present?
          sba_data = ActionController::Parameters.new(sba)
          slider_b = current_site.slider_basics.new(sba_data.permit(:name, :slug, :active))
          if slider_b.save
            if sba[:get_field_groups] # save group fields
              save_field_group(slider_b, sba[:get_field_groups])
            end
            save_field_values(slider_b, sba[:field_values])
            args[:messages] << "Saved Plugin Slider Basic: #{slider_b.name}"
          end
        end
      end
    end
  end

  # here all actions on plugin destroying
  # plugin: plugin model
  def slider_basic_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def slider_basic_on_active(plugin)
    unless ActiveRecord::Base.connection.table_exists? 'plugins_slider_basic'
      ActiveRecord::Base.connection.create_table :plugins_slider_basic do |t|
        t.string :name, :slug, :image, :kind
        t.integer :site_id, :parent_id
        t.integer :active, default: 1
        t.timestamps
      end
    end
  end

  # here all actions on going to inactive
  # plugin: plugin model
  def slider_basic_on_inactive(plugin)

  end

  # Mios
  def slider_basic_app_before_load
    Site.class_eval do
      #attr_accessible :my_id
      has_many :slider_basics, :class_name => "Plugins::SliderBasic::Models::SliderBasic", foreign_key: :site_id, dependent: :destroy
    end
  end

  def slider_basic_front_before_load
    shortcode_add('slider_basic',  plugin_view("slider_basic", "slider_basic_shorcode"))
  end

  def slider_basic_admin_before_load
      items_i = []
      items_i << {icon: "list", title: "#{t('admin.post_type.all')}", url: admin_plugins_slider_basic_sliders_path}
      items_i << {icon: "plus", title: "#{t('admin.post_type.add_new')}", url: new_admin_plugins_slider_basic_slider_path}
      admin_menu_append_menu_item("appearance", {icon: "image", title: "#{t('plugin.slider_basic.title')}", url: "", items: items_i})  if can? :manager, :settings
  end

end