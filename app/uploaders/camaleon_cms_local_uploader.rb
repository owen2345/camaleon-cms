class CamaleonCmsLocalUploader < CamaleonCmsUploader
  PRIVATE_DIRECTORY = 'private'
  # return the full file path for private file with key
  # sample: 'my_file.pdf' ==> /var/www/my_app/private/my_file.pdf
  def self.private_file_path(key, current_site)
    Rails.root.join(self::PRIVATE_DIRECTORY, current_site.id.to_s, key.gsub(/(\/){2,}/, "/")).to_s
  end

  # check if this uploader is private mode
  def is_private_uploader?
    @args[:private]
  end

  def after_initialize
    if is_private_uploader?
      @root_folder = Rails.root.join(self.class::PRIVATE_DIRECTORY, @current_site.id.to_s).to_s
    else
      @root_folder = @args[:root_folder] || @current_site.upload_directory
    end
    FileUtils.mkdir_p(@root_folder) unless Dir.exist?(@root_folder)
  end

  #
  def add_file(uploaded_io_or_file_path, key, args = {})
    args = { same_name: false, is_thumb: false }.merge(args)

    # add folder if not exists
    add_folder(File.dirname(key), args[:is_thumb]) if File.dirname(key).present?

    # upload file to the right place
    upload_io = uploaded_io_or_file_path.is_a?(String) ? File.open(uploaded_io_or_file_path) : uploaded_io_or_file_path
    File.open(File.join(@root_folder, key), 'wb') { |file| file.write(upload_io.read) }

    # interrupt process if thumbnail
    return {} if args[:is_thumb]

    # in case there is an alternative custom uploader
    @instance.hooks_run('uploader_local_before_upload', file: uploaded_io_or_file_path, key: key, args: args)

    # Create DB record or override
    media_file = CamaleonCms::Media.find_or_create_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key)
    ) do |f|

      f.file_size = args[:file_size]
      f.file_type = CamaleonCmsUploader.get_file_format(key)
      f.url = "/media/#{@current_site.id}" + key # being local, the files path can be relative
    end

    # Possible media error validations like duplications
    return media_file.errors.messages unless media_file.valid?

    media_file
  end

  def add_folder(key, is_thumb = false)
    dir = File.join(@root_folder, key).to_s
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

    return if is_thumb || key == '/'

    media_folder = CamaleonCms::Media.find_or_create_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key),
      is_folder: true
    )

    media_folder
  end

  def delete_folder(key)
    main_folder = CamaleonCms::Media.find_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key),
      is_folder: true
    )

    files = CamaleonCms::Media.where(site_id: @current_site.id, folder_path: key)
    inner_folders_files = CamaleonCms::Media.where(site_id: @current_site.id)
                                            .where('folder_path like ?', key + '/%')

    if main_folder.present?
      # destroy from DB
      main_folder.destroy
      files.destroy_all
      inner_folders_files.destroy_all

      # destroy in filesystem
      folder = File.join(@root_folder, key)
      FileUtils.rm_rf(folder) if Dir.exist? folder
    end

    @instance.hooks_run('after_delete_folder', key)
  end

  def delete_file(key)
    media_file = CamaleonCms::Media.find_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key)
    )

    # destroy from db
    media_file.destroy if media_file.present?

    # destroy in filesystem
    file = File.join(@root_folder, key)
    FileUtils.rm(file) if File.exist? file

    # destroy thumbnail also from filesystem
    key = CamaleonCmsUploader.thumbnail(key)
    file = File.join(@root_folder, key)
    FileUtils.rm(file) if File.exist? file

    @instance.hooks_run('after_delete_file', key)
  end
end
