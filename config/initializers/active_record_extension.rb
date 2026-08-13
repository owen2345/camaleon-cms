ActiveRecord::Associations::CollectionProxy.class_eval do
  # order a collection by custom fields
  # Arguments:
  # key: (String) Custom field key
  # order: (String) order direction (ASC | DESC)
  # sample: CamaleonCms::Site.first.posts.sort_by_field("untitled-field-attributes", "desc")
  def sort_by_field(key, order = 'ASC')
    cfr_table = CamaleonCms::CustomFieldsRelationship.table_name
    # Security (audit 2026-08-11, Tier-2 #8): sort_by_field is a public API themes/plugins reach as
    # sort_by_field(key, params[:order]), so interpolating `order` straight into ORDER BY was an
    # injection sink. Whitelist the direction to ASC/DESC and order by a quoted Arel column, so a
    # hostile direction can neither append extra ORDER BY terms nor raise -- without relying on
    # ActiveRecord's implicit raw-SQL guard.
    direction = order.to_s.casecmp?('DESC') ? :desc : :asc
    joins("LEFT OUTER JOIN #{cfr_table} ON #{cfr_table}.objectid = #{build.class.table_name}.id").where(
      "#{cfr_table}.custom_field_slug = ? and #{cfr_table}.object_class = ?", key, build.class.name.parseCamaClass
    ).reorder(CamaleonCms::CustomFieldsRelationship.arel_table[:value].public_send(direction))
  end

  # Filter by custom field values
  # Arguments:
  # key: (String) Custom field key
  # sample: my_posts_that_include_my_field = CamaleonCms::Site.first.posts.filter_by_field("untitled-field-attributes")
  #   this will return all posts of the first site that include custom field "untitled-field-attributes"
  #   additionally, you can add extra filter:
  # my_posts_that_include_my_field
  #   .where("#{CamaleonCms::CustomFieldsRelationship.table_name}.value=?", "my_value_for_field")
  def filter_by_field(key, args = {})
    cfr_table = CamaleonCms::CustomFieldsRelationship.table_name
    res = joins("LEFT OUTER JOIN #{cfr_table} ON #{cfr_table}.objectid = #{build.class.table_name}.id").where(
      "#{cfr_table}.custom_field_slug = ? and #{cfr_table}.object_class = ?", key, build.class.name.parseCamaClass
    )
    res = res.where("#{cfr_table}.value = ?", args[:value]) if args[:value]
    res
  end
end
