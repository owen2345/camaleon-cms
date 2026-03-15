class AddConfirmTokenToUsers < CamaManager.migration_class
  def change
    add_column CamaleonCms::User.table_name, :confirm_email_token, :string, default: nil, if_not_exists: true
    add_column CamaleonCms::User.table_name, :confirm_email_sent_at, :datetime, default: nil, if_not_exists: true
    add_column CamaleonCms::User.table_name, :is_valid_email, :boolean, default: true, if_not_exists: true
  end
end
