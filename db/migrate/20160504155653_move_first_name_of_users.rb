class MoveFirstNameOfUsers < ActiveRecord::Migration
  def change
    add_column CamaleonCms::User.table_name, :first_name, :string rescue nil
    add_column CamaleonCms::User.table_name, :last_name, :string rescue nil
    CamaleonCms::User.all.each do |u|
      u.update_columns(first_name: u.get_meta('first_name'), last_name: u.get_meta('last_name')) if u.get_meta('first_name').present?
    end
  end
end
