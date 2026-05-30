class CamaleonCmsLocalUploader < CamaleonCmsUploader
  def after_initialize
    @root_folder = @current_site.upload_directory

    FileUtils.mkdir_p(@root_folder)
  end

  def setup_private_folder
    @root_folder = Rails.root.join(self.class::PRIVATE_DIRECTORY).to_s

    FileUtils.mkdir_p(@root_folder)
  end

  def browser_files(prefix = '/', _objects = {})
    path = File.join(@root_folder, prefix)

    Dir.entries(path).each do |f_name|
      next if ['..', '.', 'thumb'].include?(f_name)

      obj = file_parse(File.join(path, f_name).sub(@root_folder, '').cama_fix_media_key)
      cache_item(obj)

      browser_files(File.join(prefix, obj['name'])) if obj['is_folder']
    end
  end

  def fetch_file(file_name)
    return { error: 'Invalid file path' } unless valid_folder_path?(file_name)

    return file_name if file_exists?(file_name)

    { error: 'File not found' }
  end

  # Lists cached media objects for a folder, transparently fixing legacy thumbnail
  # URLs (see #cama_compat_legacy_thumb). The cache (media DB records) may still
  # hold thumb URLs computed from the source extension (sample: ".jpg") while the
  # on-disk thumbnail is a legacy ".png"; without this the admin media browser
  # would render 404 thumbnails for such files.
  def objects(prefix = '/', _sort = 'created_at')
    res = super
    return res if res.blank?

    res = res.to_a
    res.each { |item| cama_fix_legacy_thumb_item(item) }
    res
  end

  def file_parse(key)
    file_path = File.join(@root_folder, key)
    url_path = file_path.sub(Rails.root.join('public').to_s, '')
    is_dir = File.directory?(file_path)
    res = {
      'name' => File.basename(key),
      'folder_path' => File.dirname(key),
      'url' => if is_dir
                 ''
               elsif is_private_uploader?
                 url_path.sub("#{@root_folder}/", '')
               else
                 File.join(
                   @current_site.decorate.the_url(as_path: true, locale: false,
                                                  skip_relative_url_root: true), url_path
                 )
               end,
      'is_folder' => is_dir,
      'file_size' => is_dir ? 0 : File.size(file_path).round(2),
      'thumb' => '',
      'file_type' => self.class.get_file_format(file_path),
      'dimension' => ''
    }.with_indifferent_access
    res['key'] = File.join(res['folder_path'], res['name'])
    if res['file_type'] == 'image' && File.extname(file_path).downcase != '.gif'
      res['thumb'] = if is_private_uploader?
                       "/admin/media/download_private_file?file=#{version_path(key).slice(1..-1)}"
                     else
                       version_path(res['url'])
                     end
    end
    if res['file_type'] == 'image'
      res['thumb'].sub! '.svg', '.jpg'
      res['thumb'] = cama_compat_legacy_thumb(res['thumb'], version_path(key).sub('.svg', '.jpg'), res['url'])
      im = MiniMagick::Image.open(file_path)
      res['dimension'] = begin
        "#{im[:width]}x#{im[:height]}"
      rescue StandardError
        '0x0'
      end
    end
    res
  end

  # save a file into local folder
  def add_file(uploaded_io_or_file_path, key, args = {})
    args = { same_name: false, is_thumb: false }.merge(args)
    res = nil
    key = search_new_key(key) unless args[:same_name]

    if @instance # private hook to upload files by different way, add file data into result_data
      _args = { result_data: nil, file: uploaded_io_or_file_path, key: key, args: args, klass: self }
      @instance.hooks_run('uploader_local_before_upload', _args)
      return _args[:result_data] if _args[:result_data].present?
    end

    add_folder(File.dirname(key)) if File.dirname(key).present?
    upload_io = uploaded_io_or_file_path.is_a?(String) ? File.open(uploaded_io_or_file_path) : uploaded_io_or_file_path
    File.open(File.join(@root_folder, key), 'wb') { |file| file.write(upload_io.read) }
    res = cache_item(file_parse(key)) unless args[:is_thumb]
    res
  end

  # create a new folder into local directory
  def add_folder(key)
    return { error: 'Invalid folder path' } unless valid_folder_path?(key)

    d = File.join(@root_folder, key).to_s
    is_new_folder = false
    unless Dir.exist?(d)
      FileUtils.mkdir_p(d)
      is_new_folder = true if File.basename(d) != 'thumb'
    end
    f = file_parse(key)
    cache_item(f) if is_new_folder
    f
  end

  # Remove an existent folder
  def delete_folder(key)
    return { error: 'Invalid folder path' } if key.include?('..')

    folder = File.join(@root_folder, key)
    FileUtils.rm_rf(folder) if Dir.exist? folder
    get_media_collection.by_key(key).take.destroy
  end

  # Remove an existent file
  def delete_file(key)
    return { error: 'Invalid file path' } if key.include?('..')

    file = File.join(@root_folder, key)
    FileUtils.rm(file) if File.exist? file
    @instance.hooks_run('after_delete', key)
    get_media_collection.by_key(key).take.destroy
  end

  # Convert a real file path into a file key
  def parse_key(file_path)
    file_path.sub(@root_folder, '').cama_fix_media_key
  end

  private

  # Applies the legacy-thumbnail fallback (see #cama_compat_legacy_thumb) to a
  # single cached media item in place, so the admin media browser renders the
  # on-disk ".png" thumbnail instead of a 404ing ".jpg" one. No-op for folders,
  # non-image files and items without a thumb.
  # item: (CamaleonCms::Media | Hash) cached media object
  def cama_fix_legacy_thumb_item(item)
    return if item['is_folder'] || item['file_type'] != 'image' || item['thumb'].blank?

    thumb_key = version_path(File.join(item['folder_path'].to_s, item['name'].to_s))
    item['thumb'] = cama_compat_legacy_thumb(item['thumb'], thumb_key, item['url'])
  end

  # Backwards-compatibility for legacy thumbnails.
  # Older Camaleon releases stored raster thumbnails as PNG regardless of the
  # source extension (sample: "photo.jpg" => "thumb/photo-jpg.png"). The thumb
  # URL is normally derived from the source extension, so for such legacy files
  # the computed (sample: ".jpg") thumb URL would 404. Resolution order when the
  # computed thumb is missing on disk:
  #   1. a ".png" sibling exists  => point the thumb at the PNG;
  #   2. no thumbnail exists at all (sample: ".ico" favicons are never
  #      thumbnailed) => fall back to the original file url so the browser does
  #      not request a 404 thumb (the original lives one level above /thumb).
  # Otherwise the computed thumb url is returned unchanged (new uploads, PNG
  # sources and S3 are unaffected).
  # thumb_url: (String) computed public/private thumb url
  # thumb_key: (String) computed thumb media key (relative to @root_folder)
  # original_url: (String) url of the original (non-thumb) file
  def cama_compat_legacy_thumb(thumb_url, thumb_key, original_url = nil)
    return thumb_url if thumb_url.blank?

    ext = File.extname(thumb_key)
    return thumb_url if ext.blank?
    return thumb_url if file_exists?(File.join(@root_folder, thumb_key))

    unless ext.casecmp?('.png')
      png_key = thumb_key.sub(/#{Regexp.escape(ext)}\z/, '.png')
      return thumb_url.sub(/#{Regexp.escape(ext)}\z/, '.png') if file_exists?(File.join(@root_folder, png_key))
    end

    original_url.presence || thumb_url
  end
end
