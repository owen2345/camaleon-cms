=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::BootstrapEditor::BootstrapEditorHelper
  # on post editor
  # args = Hash{post: Post, post_type: Post_type}
  def bootstrap_editor_post_form(args)
    append_asset_libraries({ bootstrap_editor:{ js: [plugin_asset_path("bootstrap_editor", "js/form.js")] } })
    content_prepend("<script>var bootstrap_css_url = '#{plugin_asset_path("bootstrap_editor", "css/bootstrap.min.css")}'; </script>")
  end
end