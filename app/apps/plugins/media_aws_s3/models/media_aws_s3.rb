# class Plugins::MediaAwsS3::Models::MediaAwsS3 < ActiveRecord::Base
# attr_accessible :path, :browser_key
# belongs_to :site

# here create your models normally
# notice: your tables in database will be plugins_media_aws_s3 in plural (check rails documentation)
# end

# here your default models customization
# Site.class_eval do
#   has_many :media_aws_s3, class_name: "Plugins::MediaAwsS3::Models::MediaAwsS3"
# end

class MediaAwsS3 < ElFinderS3::CacheConnector
  #FIXME set cache methods to persist in database

  def list_objects search_parameters
    result = Plugins::MediaAwsS3::Models::MediaFilesSearchCache.find_by_query search_parameters
    result = result.nil? ? ElFinderS3::NO_CACHE : result.to_s3_result
    return result
  end

  def ls_folder(folder)
    return ElFinderS3::NO_CACHE
  end

  def update_ls_folder_results(query, response)
    if response.is_a? Seahorse::Client::Response
      result = Plugins::MediaAwsS3::Models::MediaFilesSearchCache.find_by_query query
      if (result.nil?)
        result = Plugins::MediaAwsS3::Models::MediaFilesSearchCache.new
      end

      result.put_results query, response
      result.save
      Rails.logger.info "Cache updated #{query[:bucket]}-#{query[:delimiter]}"
    end
    Rails.logger.info "Already on cache #{query[:bucket]}-#{query[:delimiter]}"
  end


  # def tree_for(hash, with_directory = true)
  #   result = []
  #   mediaFile = Plugins::MediaAwsS3::Models::MediaFilesCache.find prefix: hash
  #   if mediaFile.nil?
  #     #FIXME search with s3 connector
  #     Rails.logger.warn "Not found #{hash} on the cache"
  #   else
  #     result[:name] = mediaFile.name
  #     result[:hash] = mediaFile.hash
  #     result[:dirs] = []
  #     mediaFile.folders.split(';#;').each do |folder|
  #       result[:dirs].push(tree_for(folder, with_directory))
  #     end
  #   end
  #   #FIXME search from database
  #   # return ElFinderS3::NO_CACHE
  # end
  #
  # def ls_folder(folder)
  # FIXME search from database
  # return ElFinderS3::NO_CACHE
  # end
  # if folder == '/'
  #     result = [
  #       {
  #         name => 'a1',
  #         hash => 'a1',
  #         read => true,
  #         write => true,
  #         rm => true,
  #         hidden => false,
  #         mime => 'directory'
  #       },
  #       {
  #         name => 'a2',
  #         hash => 'a2',
  #         read => true,
  #         write => true,
  #         rm => true,
  #         hidden => false,
  #         mime => 'directory'
  #       }
  #     ]
  #   end
  #
  #   return result
  # end
  #
  # def cwd_for(pathname)
  #   {
  #     :name => pathname.basename.to_s,
  #     :hash => to_hash(pathname),
  #     :mime => 'directory',
  #     :rel => pathname.is_root? ? @options[:home] : (@options[:home] + '/' + pathname.path.to_s),
  #     :size => 0,
  #     :date => pathname.mtime.to_s,
  #   }
  #   #.merge(perms_for(pathname))
  # end
  #
  # def mkdirSuccess(folder)
  #   Rails.logger.info("Folder created: '#{folder}'")
  # end

end
