# include ApplicationHelper

# do login for admin panel and also verify if the site was created
# if site is not created, then create a new site
def init_site
  before do
    CamaleonCms::Site.delete_all
    @site = create(:site).decorate
    @post = @site.the_post('sample-post').decorate
  end

  after do
    @site = nil
    @post = nil
    Cama::Site.instance_variable_set(:@main_site, nil)
  end
end

# sign in for admin panel
# skip: true => close the skip button for intro
def admin_sign_in(user = 'admin', pass = 'admin123')
  visit "#{cama_root_relative_path}/admin/logout"
  within('#login_user') do
    fill_in 'user[username]', with: user
    fill_in 'user[password]', with: pass
  end
  click_button 'Log In'
  expect(page).to have_content 'Welcome'
  wait(2)
end

def cama_root_relative_path
  PluginRoutes.system_info['relative_url_root'].to_s if PluginRoutes.system_info['relative_url_root'].present?
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
    expect(page).to have_content p.the_title
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
