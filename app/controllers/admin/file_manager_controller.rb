class Admin::FileManagerController < AdminController

  skip_before_action :verify_authenticity_token

  def handler
    msg = {
        'result': [
            {
                "name": "joomla",
                "rights": "drwxr-xr-x",
                "size": "4096",
                "date": "2015-04-29 09:04:24",
                "type": "dir"
            }, {
                "name": "magento",
                "rights": "drwxr-xr-x",
                "size": "4096",
                "date": "2013-11-01 11:10:25",
                "type": "dir"
            }, {
                "name": "index.php",
                "rights": "-rw-r--r--",
                "size": "549923",
                "date": "2013-11-01 11:44:13",
                "type": "file"
            }
        ]
    }
    render :json => msg, :status => 200
  end

end