class Api::V1::CategorySerializer < Api::BaseSerializer
  attributes :id, :name, :slug, :count, :post_type_parent_name

  def post_type_parent_name
    object.post_type_parent.name
  end

end