class MoveFirstNameOfUsers < ActiveRecord::Migration
  def change
    add_column CamaleonCms::User.table_name, :first_name, :string unless column_exists?(CamaleonCms::User.table_name, :first_name)
    add_column CamaleonCms::User.table_name, :last_name, :string unless column_exists?(CamaleonCms::User.table_name, :last_name)
    CamaleonCms::User.all.each do |u|
      u.update_columns(first_name: u.get_meta('first_name'), last_name: u.get_meta('last_name')) if u.get_meta('first_name').present?
    end
  end
end
