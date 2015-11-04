#
# http://elrte.org/redmine/projects/elfinder/wiki/Client-Server_Protocol_EN
#

require 'base64'

#TODO remove with elfinder?
module ElFinder
  # Represents ElFinder connector on Rails side.
  class Connector
    def _resize
      if image_handler.nil?
        command_not_implemented
      else
        if @target.file?
          perms = perms_for(@target)
          if perms[:read] == true && perms[:write] == true
            case @params[:mode]
              when 'crop'
                image_handler.crop(@target, :width => @params[:width].to_i, :height => @params[:height].to_i, :x => @params[:x].to_i, :y => @params[:y].to_i)
              when 'rotate'
                image_handler.rotate(@target, :degree => @params[:degree].to_i)
              else
                image_handler.resize(@target, :width => @params[:width].to_i, :height => @params[:height].to_i)
            end
            if (thumbnail = thumbnail_for(@target)).file?
              thumbnail.unlink
            end

            # remove_target(@target)
            # @target = @target_new

            @response[:select] = [to_hash(@target)]
            _open(@current)
          else
            @response[:error] = 'Access Denied'
          end
        else
          @response[:error] = "Unable to resize file. It does not exist"
        end
      end
    end

    private
    def thumbnail_for(pathname)
      @thumb_directory + "#{pathname.path.to_s.parameterize}.png"
    end
  end

  class Image
    def self.resize(pathname, options = {})
      return nil unless File.exist?(pathname)
      system( ::Shellwords.join(['convert', '-resize', "#{options[:width]}x#{options[:height]}", pathname.to_s, pathname.to_s]) )
    end
    def self.crop(pathname, options = {})
      return nil unless File.exist?(pathname)
      system( ['convert', '-crop', "#{options[:width]}x#{options[:height]}+#{options[:x]}+#{options[:y]}", pathname.to_s, pathname.to_s].join(' ') )
    end
    def self.rotate(pathname, options = {})
      return nil unless File.exist?(pathname)
      system( ['convert', '-rotate', "#{options[:degree]}", pathname.to_s, pathname.to_s].join(' ') )
    end
  end
end
