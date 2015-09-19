class Plugins::MediaAwsS3::Models::MediaFilesSearchCache < ActiveRecord::Base
  attr_accessible :bucket, :delimiter, :encoding_type, :max_keys, :prefix, :common_prefixes_raw, :last_sync, :content_files_raw

  @contents_value
  @common_prefixes_value
  @getting_from_cache_value

  def self.find_by_query query
    Plugins::MediaAwsS3::Models::MediaFilesSearchCache.find_by (
                                                                 {:bucket => query[:bucket],
                                                                  :delimiter => query[:delimiter],
                                                                  :encoding_type => query[:encoding_type],
                                                                  :max_keys => query[:max_keys],
                                                                  :prefix => query[:prefix]
                                                                 }
                                                               )
  end

  def put_results(query, results)
    self.content_files_raw = to_content_files_to_raw results.contents
    self.common_prefixes_raw = to_common_prefixes_to_raw results.common_prefixes
    self.bucket = query[:bucket]
    self.delimiter = query[:delimiter]
    self.encoding_type = query[:encoding_type]
    self.max_keys = query[:max_keys]
  end

  def to_s3_result
    @contents_value = from_content_files_raw self.content_files_raw
    @common_prefixes_value = from_common_prefixes_raw self.common_prefixes_raw
    @getting_from_cache_value = true
    return self
  end

  def contents
    return @contents_value
  end

  def common_prefixes
    return @common_prefixes_value
  end

  def getting_from_cache
    return @getting_from_cache_value
  end



  private

  # def to_content_files_raw_row key, etag, last_modified, content_size
  #   "#{content.key},;,#{content.etag},;,#{content.last_modified},;,#{content.size}"
  # end
  #
  # def to_common_prefixes_raw_row name, hash
  #   "#{name},;,#{hash}"
  # end

  def to_content_files_to_raw content
    content_files_raw_rows = []
    content.each do |e|
      content_files_raw_rows.push [e.key, e.etag, e.last_modified, e.size] * '###'
    end
    content_files_raw_rows * '-#-'
  end

  def from_content_files_raw content_files_raw
    result = []
    rows = content_files_raw.split('-#-')
    rows.each do |r|
      element = r.split('###')
      if element.count == 4
        result.push({:key => element[0], :etag => element[1], :last_modified => element[2], :size => element[3]})
      end
    end
    return result
  end

  def to_common_prefixes_to_raw common_prefixes
    common_prefix_raw_rows = []
    common_prefixes.each do |folder|
      common_prefix_raw_rows.push [folder.prefix, folder.prefix] * '###'
    end
    common_prefix_raw_rows * '-#-'
  end

  def from_common_prefixes_raw common_prefixes_raw
    result = []
    rows = common_prefixes_raw.split('-#-')
    rows.each do |r|
      element = r.split('###')
      if element.count == 2
        result.push({:prefix => element[0], :hash => element[1]})
      end
    end
    return result
  end

end
