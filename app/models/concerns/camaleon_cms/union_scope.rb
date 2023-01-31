# frozen_string_literal: true

module CamaleonCms
  module UnionScope
    extend ActiveSupport::Concern
    included do
      def self.union_scope(*scopes)
        id_column = "#{table_name}.id"
        sub_query = scopes.map { |s| s.select(id_column).to_sql.presence || nil }.compact.join(" UNION ")
        where "#{id_column} IN (#{sub_query})"
      end
    end
  end
end
