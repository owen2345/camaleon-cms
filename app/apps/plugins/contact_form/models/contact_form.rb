=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::ContactForm::Models::ContactForm < ActiveRecord::Base
  attr_accessible :site_id, :name, :description, :count, :slug, :value, :settings, :parent_id

  belongs_to :site, class_name: "Site", foreign_key: :site_id
  belongs_to :post, class_name: "Post", foreign_key: :parent_id
  has_many :responses, :class_name => "Plugins::ContactForm::Models::ContactForm", :foreign_key => :parent_id, dependent: :destroy
  validates :name, presence: true
  validates_uniqueness_of :slug, scope: :site_id

  before_validation :before_validating

  private
  def before_validating
    slug = self.slug
    slug = self.name if slug.blank?
    self.slug = slug.to_s.parameterize
  end
end
