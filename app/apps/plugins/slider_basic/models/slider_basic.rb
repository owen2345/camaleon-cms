=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::SliderBasic::Models::SliderBasic < ActiveRecord::Base
  # here create your models normally
  # notice: your tables in database will be plugins_slider_basic in plural (check rails documentation)
  attr_accessible :name, :slug, :parent_id, :site_id, :active, :image, :kind, :captions
  attr_accessor :captions
  self.table_name = "plugins_slider_basic"
  include CustomFieldsRead

  belongs_to :site, :class_name => "Site", foreign_key: :site_id
  scope :main, -> {where(parent_id: nil)}
  scope :actives, -> {where(active: 1)}
  validates :name, presence: true
  before_validation :before_validating
  after_create :check_fields

  def _get_field_groups
    if self.get_field_groups.size > 0
      self.get_field_groups
    else
      create_field_groups
    end
  end

  # check if this slider is text mode
  def text_mode?
    self.kind == "text"
  end

  def image_mode?
    self.kind == "image"
  end


  private
  def create_field_groups
    group1 = self.add_custom_field_group({name: 'Image Slides', slug: 'plugin_slider_basic_slider_images', status: 'sliders'})
    group1.add_manual_field({"name"=> "Images", slug: "images", "description"=>"Images Sliders"}, {field_key: "image", required: true, multiple: true })
    group1.add_manual_field({"name"=> "Captions", slug: "captions", "description"=>"Captions in Sliders"}, {field_key: "text_box", required: false, multiple: true, translate: true }) unless(self.captions || true)

    group2 = self.add_custom_field_group({name: 'Text Slides', slug: 'plugin_slider_basic_slider_texts', status: 'sliders'})
    group2.add_manual_field({"name"=> "Text", slug: "text-slides"}, {field_key: "editor", required: true, multiple: true, translate: true })

    [group1, group2]
  end

  def check_fields
    create_field_groups unless self.get_field_groups.where(slug: "plugin_slider_basic_slider_images").present?
  end

  def before_validating
    self.slug = self.name if self.slug.blank?
    self.slug = self.slug.to_s.parameterize
  end
end
