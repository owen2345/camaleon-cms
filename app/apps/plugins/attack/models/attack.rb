module Plugins
  module Attack
    module Models
      class Attack < ApplicationRecord
        belongs_to :site, class_name: 'CamaleonCms::Site'
      end
    end
  end
end
