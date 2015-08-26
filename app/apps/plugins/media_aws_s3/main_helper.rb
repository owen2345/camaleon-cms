module Plugins::MediaAwsS3::MainHelper

  def self.included(klass)
    #klass.helper_method [:my_helper_method] rescue "" # here your methods accessible from views
  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def media_aws_s3_on_active(plugin)
    unless ActiveRecord::Base.connection.table_exists? 'plugins_media_files_search_caches'
      ActiveRecord::Base.connection.create_table :plugins_media_files_search_caches do |t|
        t.integer :max_keys
        t.string :bucket, :delimiter, :encoding_type, :prefix
        t.text :common_prefixes_raw, :content_files_raw
        t.timestamps :last_sync, null:false
      end
    end
  end

  # here all actions on going to inactive
  # plugin: plugin model
  def media_aws_s3_on_inactive(plugin)
    if ActiveRecord::Base.connection.table_exists? 'plugins_media_files_search_caches'
      ActiveRecord::Base.connection.drop_table :plugins_media_files_search_caches
    end
  end

end
