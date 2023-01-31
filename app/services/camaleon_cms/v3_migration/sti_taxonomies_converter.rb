# frozen_string_literal: true

module CamaleonCms
  module V3Migration
    class StiTaxonomiesConverter < ApplicationService
      def call
        @failed = []
        CamaleonCms::TermTaxonomy.find_each(&method(:parse_taxonomy))
        log('Following taxonomies failed parsing class name (skipped)', :error, @failed) if @failed.any?
      end

      def self.revert
        nil
      end

      private

      def parse_taxonomy(model)
          name = model.taxonomy
          name = 'Widget::Sidebar' if name == 'sidebar'
          name = 'Widget::Main' if name == 'widget'
          model.update_column(:type, "CamaleonCms::#{name.classify}".constantize.name)
      rescue => e
        @failed.push([model.taxonomy, e.message])
      end
    end
  end
end
