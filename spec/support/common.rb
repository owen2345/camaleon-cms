# include ApplicationHelper

# do login for admin panel and also verify if the site was created
# if site is not created, then create a new site
def login_success
  Rails.logger.info "^^^^^^^^^^^^^^^^^^^^^#{root_url}"
  unless CamaleonCms::Site.any?
    it "Verify Install Camaleon" do
      visit "#{root_url}/admin/installers"
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
  visit "#{root_url}/admin/login"
  within("#login_user") do
    fill_in 'user_username', :with => user
    fill_in 'user_password', :with => pass
  end
  click_button 'Log In'
  expect(page).to have_content 'Welcome'

  click_link "Skip" if close
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
  ActiveRecord::Base.connection.execute("END;")
  ActiveRecord::Base.connection.execute("BEGIN TRANSACTION;")
end