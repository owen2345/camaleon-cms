# include ApplicationHelper

# expose the suite-wide shared site (see spec/support/shared_site.rb) as @site.
# fresh: true replaces it with a site created inside the example's transaction —
# needed by feature specs whose site slug must match the Capybara server host
# (multi-site resolution matches request host against slugs once a second site
# exists).
def init_site(fresh: false)
  before do
    if fresh
      CamaleonCms::Site.delete_all
      @site = create(:site).decorate
    else
      @site = (CamaleonCms::Site.first || create(:site)).decorate
    end
    @post = @site.the_post('sample-post').decorate
  end

  after do
    @site = nil
    @post = nil
  end
end

# sign in for admin panel by setting the auth cookie directly (the browser
# must be on the app's origin to accept it, hence the static bootstrap visit).
# The form-driven flow is covered by admin_form_sign_in in the dedicated
# sign-in specs; the password is still verified here so a wrong one fails
# loudly instead of silently producing a signed-out session.
def admin_sign_in(username = 'admin', pass = 'admin123')
  user = CamaManager.get_user_class_name.constantize.find_by!(username: username)
  raise ArgumentError, "wrong password for #{username}" unless user.authenticate(pass)

  visit '/favicon.ico' unless page.current_url.start_with?('http')
  page.driver.browser.manage.add_cookie(name: 'auth_token', value: "#{user.auth_token}&rspec&127.0.0.1")
end

# sign in for admin panel through the real login form; use only for specs that
# test the sign-in flow itself (the login page also says "Welcome", so assert
# the dashboard path rather than page text).
def admin_form_sign_in(user = 'admin', pass = 'admin123')
  # Ensure a clean, signed-out session first. A GET to /admin/logout no longer ends a session (it
  # renders a confirmation now), so clear the auth cookie directly, then land on the login form.
  visit '/favicon.ico' unless page.current_url.start_with?('http')
  page.driver.browser.manage.delete_cookie('auth_token')
  visit "#{cama_root_relative_path}/admin/login"
  within('#login_user') do
    fill_in 'user[username]', with: user
    fill_in 'user[password]', with: pass
  end
  click_button 'Log In'
  expect(page).to have_current_path(%r{/admin/dashboard}, ignore_query: true)
end

def cama_root_relative_path
  PluginRoutes.system_info['relative_url_root'].presence&.to_s
end

def file_select
  attach_file('Select files to upload', "/Users/owen/Pictures/luna\ miel/DSC00116.JPG ")
end

def eval_code(code)
  instance_eval(code)
end

def wait(time)
  sleep(time)
end

# return the id of the first post
def get_content_attr(post_type = 'post', attr = 'id', pos = 'first')
  Cama::Site.first.decorate.the_post_type(post_type).decorate.the_posts.send(pos).decorate.send(attr)
  # fix_db
end

# return the id of the first post
def get_cat_attr(attr = 'id', pos = 'first')
  res = Cama::Site.first.decorate.the_full_categories.decorate.send(pos).send(attr)
  fix_db
  res
end

# return the id of the first post
def get_tag_attr(attr = 'id', pos = 'first')
  puts "----------------#{Cama::Site.first.decorate.the_tags.to_a.inspect}"
  res = Cama::Site.first.decorate.the_tags.decorate.send(pos).send(attr)
  fix_db
  res
end

# fix for: SQLite3::BusyException: database is locked: commit transaction
def fix_db
  return unless ActiveRecord::Base.connection.adapter_name.downcase.include?('sqlite')

  begin
    ActiveRecord::Base.connection.execute('END;')
  rescue StandardError
    SQLite3::SQLException
  end
  # ActiveRecord::Base.connection.execute("BEGIN TRANSACTION;")
end

def pages_test
  current_site = Cama::Site.first.decorate
  page1 = current_site.the_post_type('post').add_post(title: 'test1', content: "content [data key='subtitle']",
                                                      summary: 'summary', order_position: 2)
  page1.add_field({ 'name' => 'Sub Title', 'slug' => 'subtitle' },
                  { 'field_key' => 'text_box', 'translate' => true, default_value: 'test sub title' })
  page1.set_settings({ has_summary: true, default_template: 'home/page2', has_picture: true })
  visit(page1.the_title)

  current_site.the_contents.decorate.each do |p|
    visit p.the_url(as_path: true).to_s
    expect(page).to have_text p.the_title
  end
  the_tags.decorate.send(pos).send(attr)
end

# create a new post type for first site
def create_test_post_type(args = {})
  @site.post_types.create!(
    { name: 'Test', slug: 'test', description: 'this is a test', data_options: {} }.merge!(args)
  )
end

# create a new post for post type
def create_test_post(post_type, args = {})
  post_type.posts.create!({ title: 'Test post', slug: 'test', content: 'this is a test', data_options: {} }.merge(args))
end

def confirm_dialog
  case page.driver.class.to_s
  when 'Capybara::Selenium::Driver'
    begin
      page.driver.browser.switch_to.alert.accept
    rescue StandardError
      Selenium::WebDriver::Error::NoSuchAlertError
    end
  when 'Capybara::Webkit::Driver'
    sleep 1 # prevent test from failing by waiting for popup

    silence_warnings do
      page.driver.accept_js_confirms!
    end
  else
    raise 'Unsupported driver'
  end
end

# Temporarily replace the CamaleonCmsUploader.delete_block (without calling the
# public setter) for the duration of the given block. This helper uses
# instance_variable_set/get to avoid invoking the public `delete_block` method
# which might be observed by test spies. Example:
#
#   with_delete_block(proc { |settings, uploader, key| uploader.delete_file(key) }) do
#     # run code that triggers the delete_block
#   end
#
def with_delete_block(temp_proc)
  old = CamaleonCmsUploader.instance_variable_get(:@delete_block)
  CamaleonCmsUploader.instance_variable_set(:@delete_block, temp_proc)
  yield
ensure
  CamaleonCmsUploader.instance_variable_set(:@delete_block, old)
end
