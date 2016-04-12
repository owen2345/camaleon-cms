# include ApplicationHelper
require 'rails_helper'

# do login for admin panel and also verify if the site was created
# if site is not created, then create a new site
def login_success
  unless CamaleonCms::Site.any?
    #ActiveRecord::Base.connection.execute("BEGIN TRANSACTION; END;")
    it "Verify Install Camaleon" do
      visit "#{cama_root_path}/admin/installers"
      within("#new_site") do
        fill_in 'site_name', :with => 'Test Site'
        select "Default Theme", from: "theme"
      end
      click_button 'Submit'
      expect(page).to have_content 'successfully'
    end
  end

  it "signs me in" do
    admin_sign_in(true)
  end
end

# sign in for admin panel
# skip: true => close the skip button for intro
def admin_sign_in(close = false, user = "admin", pass = "admin")
  visit "#{cama_root_path}/admin/login"
  within("#login_user") do
    fill_in 'user_username', :with => user
    fill_in 'user_password', :with => pass
  end
  click_button 'Log In'
  expect(page).to have_content 'Welcome'

  click_link "Skip" if close
end

def cama_root_path
  "/#{PluginRoutes.system_info["relative_url_root"]}" if PluginRoutes.system_info["relative_url_root"].present?
end

# open file manager modal and upload a new file
# TODO
def file_select
  attach_file("Select files to upload", "/Users/owen/Pictures/luna\ miel/DSC00116.JPG ")
end

def eval_code(code)
  instance_eval(code)
end

def wait(time)
  sleep(time)
end

# return the id of the first post
def get_content_attr(post_type = "post", attr = "id", pos = "first")
  res = Site.first.decorate.the_post_type(post_type).decorate.the_posts.send(pos).decorate.send(attr)
  fix_db
  res
end

# return the id of the first post
def get_cat_attr(attr = "id", pos = "first")
  res = Site.first.decorate.the_full_categories.decorate.send(pos).send(attr)
  fix_db
  res
end

# return the id of the first post
def get_tag_attr(attr = "id", pos = "first")
  res = Site.first.decorate.the_tags.decorate.send(pos).send(attr)
  fix_db
  res
end

# fix for: SQLite3::BusyException: database is locked: commit transaction
def fix_db
  # ActiveRecord::Base.connection.execute("END;")
  # ActiveRecord::Base.connection.execute("BEGIN TRANSACTION;")
end

def pages_test
  current_site = Cama::Site.first.decorate
  page1 = current_site.the_post_type("post").add_post(title: "test1", content: "content [data key='subtitle']", summary: "summary", order_position: 2)
  page1.add_field({"name"=>"Sub Title", "slug"=>"subtitle"}, {"field_key"=>"text_box", "translate"=>true, default_value: "test sub title"})
  page1.set_settings({has_summary: true, default_template: "home/page2", has_picture: true})
  visit(page1.the_title)

  current_site.the_contents.decorate.each do |p|
    visit "#{p.the_url(as_path: true)}"
    expect(page).to have_content p.the_title
  end
  the_tags.decorate.send(pos).send(attr)
end

# return the current for testing case
def get_current_test_site
  Cama::Site.first || create_test_site
end

# create a new post type for first site
def create_test_post_type(args = {})
  get_current_test_site.post_types.create({name: 'Test', slug: 'test', description: 'this is a test', data_options: {}}.merge(args))
end

# create a test site
def create_test_site(args = {})
  Cama::Site.create({slug: 'test', name: 'Test Site'}.merge(args))
end