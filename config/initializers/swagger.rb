Swagger::Docs::Config.register_apis(
  {
    '1.0' => {
      :api_extension_type => :json,
      :api_file_path => "public/",
      :clean_directory => false,
      :attributes => {
        :info => {
          'title' => 'Camaleon CMS API Docs',
          'description' => 'This is the api documentation',
          'contact' => 'owenperedo@gmail.com',
          'license' => 'AGPLv3',
          'licenseUrl' => 'http://camaleon.tuzitio.com/license.html/'
        }
      }
    }
  }
)
