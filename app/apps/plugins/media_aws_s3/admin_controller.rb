class Plugins::MediaAwsS3::AdminController < Apps::PluginsAdminController
  include Plugins::MediaAwsS3::MainHelper
  include ElFinderS3::Action

  def index
    # here your actions for admin panel
  end

  # here add your custom functions

  def elfinder
    dirname = "/media/#{current_site.id}"
    r = {dirname: dirname}; hooks_run("elfinder", r)
    dirname = r[:dirname]
    dir = File.join(Rails.public_path, dirname)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    h, r = ElFinderS3::Connector.new(
      :mime_handler => ElFinderS3::MimeType,
      :root => dir,
      :url => dirname,
      :thumbs => true,
      :thumbs_size => 100,
      :thumbs_directory => 'thumbs',
      :home => t("admin.media.home"),
      :original_filename_method => lambda { |file| "#{File.basename(file.original_filename, File.extname(file.original_filename)).parameterize}#{File.extname(file.original_filename)}" },
      :default_perms => {:read => true, :write => true, :rm => true, :hidden => false},
    ).run(params)

    headers.merge!(h)

    render (r.empty? ? {:nothing => true} : {:text => r.to_json}), :layout => false
  end

end
