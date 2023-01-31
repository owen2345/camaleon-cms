# frozen_string_literal: true

module CamaleonCms
  module V3Migration
    class StiPostsConverter < ApplicationService
      def call
        @failed = []
        CamaleonCms::PostDefault.find_each(&method(:parse_post))
        log('Following posts failed parsing class name (skipped)', :error, @failed) if @failed.any?
      end

      def self.revert
        nil
      end

      private

      def parse_post(model)
          name = model.post_class
          name = 'CamaleonCms::Post' if name == 'Post'
          model.update_column(:type, name.constantize.name)
      rescue => e
        @failed.push([model.post_class, e.message])
      end
    end
  end
end
