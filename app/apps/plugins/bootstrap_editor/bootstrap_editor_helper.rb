module Plugins::BootstrapEditor::BootstrapEditorHelper
  # on post editor
  # args = Hash{post: Post, post_type: Post_type}
  def bootstrap_editor_post_form(args)
    append_asset_libraries({ bootstrap_editor:{ js: [plugin_asset_path("bootstrap_editor", "js/form.js")] } })
    content_prepend("<script>var bootstrap_css_url = '#{plugin_asset_path("bootstrap_editor", "css/bootstrap.min.css")}'; </script>")
  end
end