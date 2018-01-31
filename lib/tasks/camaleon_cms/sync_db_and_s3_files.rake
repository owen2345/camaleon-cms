namespace :camaleon_cms do
  require 'aws-sdk'

  # call: rake camaleon_cms:sync_db_and_s3_files
  desc 'Create/Recreate Contents mapping on ElasticSearch'
  task sync_db_and_s3_files: :environment do
    time = Time.now
    puts time

    map_aws_to_database
    create_folders

    puts Time.now.to_s
    puts 'Took:' + (Time.now - time).to_s
  end

  def map_aws_to_database
    cloudfront = current_site.get_option('filesystem_s3_cloudfront')
    aws_region = current_site.get_option('filesystem_region', 'us-west-2')
    aws_akey = current_site.get_option('filesystem_s3_access_key')
    aws_asecret = current_site.get_option('filesystem_s3_secret_key')
    aws_bucket = current_site.get_option('filesystem_s3_bucket_name')

    credentials = Aws::Credentials.new(aws_akey, aws_asecret)
    s3 = Aws::S3::Client.new(region: aws_region, credentials: credentials)

    # Process files (no thumbnails)
    s3.list_objects(bucket: aws_bucket).each do |response|
      response.contents.each do |rec|
        next if rec.key.index('/thumb/').present? || rec.key.start_with?('thumb/') # no thumbnails

        # catch folders w/ size == 0
        if rec.size.zero?
          create_folder(rec.key)
          next
        end

        # else: is a file
        CamaleonCms::Media.find_or_create_by(
          site_id: current_site.id,
          name: rec.key.split('/').last,
          folder_path: CamaleonCmsUploader.folder_path(rec.key)
        ) do |f|

          f.file_size = rec.size
          f.file_type = CamaleonCmsUploader.get_file_format(rec.key)
          f.url = cloudfront + '/' + rec.key
          f.updated_at = rec.last_modified
        end
      end
    end
  end

  def create_folders
    # Process (more) folders from inserted data
    CamaleonCms::Media.pluck(:folder_path).uniq.each do |folder|
      next if folder == '/'

      splitted_folder = folder.split('/').reject(&:empty?)
      splitted_folder.each_index do |index|
        # each one of the subfolders have to be created separately
        subfolder = splitted_folder.first(index + 1).join('/')
        create_folder(subfolder)
      end
    end
  end

  def create_folder(path)
    CamaleonCms::Media.find_or_create_by(
      site_id: current_site.id,
      name: path.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(path),
      is_folder: true
    )
  end

  def current_site
    @site || @site = CamaleonCms::Site.first
  end
end
