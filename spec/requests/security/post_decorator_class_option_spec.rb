# frozen_string_literal: true

# A post type's cama_post_decorator_class option names the class camaleon_cms loads to decorate every
# post of the type, and post type options are written by plugin and theme save hooks from request
# params. Through such a hook a settings manager, who may edit post types, could name any class.
# This spec plays that hook: a class outside the decorator hierarchy is refused for everyone, the
# option stays unset and the posts keep the default decorator, while a post decorator is stored.
# OpenSpec: post-decorator-class-integrity.
RSpec.describe 'the post decorator class option written by a post type save hook', type: :request do
  init_site

  let(:post_type) { @post.post_type }
  let(:settings_role) { @site.user_roles.create!(name: 'Settings manager', slug: 'settings-mgr-decorator') }
  let(:settings_manager) { create(:user, role: settings_role.slug, site: @site) }
  let(:option) { 'cama_post_decorator_class' }

  before do
    settings_role.set_meta("_manager_#{@site.id}", { 'settings' => 1 })
    @hook_ids = []
  end

  after { @hook_ids.each { |id| PluginRoutes.remove_anonymous_hook('updated_post_type', id) } }

  # A save hook storing the given class name as the saved post type's decorator, torn down after the
  # example: what a plugin hook writing request params amounts to.
  def hook_storing_decorator(class_name)
    id = "decorator-#{class_name.parameterize}"
    @hook_ids << id
    PluginRoutes.add_anonymous_hook('updated_post_type',
                                    ->(args) { args[:post_type].set_options(option => class_name) }, id)
  end

  def save_post_type
    patch "/admin/settings/post_types/#{post_type.id}",
          params: { post_type: { name: post_type.name, slug: post_type.slug } }
  end

  def expect_refused(class_name)
    expect(response).to have_http_status(:found)
    expect(flash[:error]).to include(option).and include(class_name)
    expect(CamaleonCms::PostType.find(post_type.id).get_option(option)).to be_nil
    expect(CamaleonCms::Post.find(@post.id).decorator_class).to eq(CamaleonCms::PostDecorator)
  end

  it 'refuses a class outside the decorator hierarchy for a settings manager' do
    hook_storing_decorator('Object')
    sign_in_as(settings_manager, site: @site)

    save_post_type

    expect_refused('Object')
  end

  it 'refuses it for an administrator as well' do
    hook_storing_decorator('Object')
    sign_in_as(create(:user_admin, site: @site), site: @site)

    save_post_type

    expect_refused('Object')
  end

  # The admin flash is rendered raw, so the refusal quotes a value only when it is a class name, and
  # never at a length the session cookie cannot hold.
  it 'does not echo a refused value that is not a class name' do
    payload = '<img src=x onerror=alert(1)>'
    hook_storing_decorator(payload)
    sign_in_as(create(:user_admin, site: @site), site: @site)

    save_post_type

    expect(flash[:error]).to include(option)
    expect(flash[:error]).not_to include('<img')
    follow_redirect!
    expect(response.body).not_to include(payload)
  end

  it 'answers an overlong refused class name with the flash refusal' do
    hook_storing_decorator("Probe#{'x' * 5000}")
    sign_in_as(create(:user_admin, site: @site), site: @site)

    save_post_type

    expect(response).to have_http_status(:found)
    expect(flash[:error]).to include(option)
    expect(flash[:error].length).to be < 400
  end

  # A refusal raised while serving a page is no save the user submitted: redirecting would land on a
  # page that refuses again, round and round, so it is raised, as before the check existed.
  it 'raises a refusal that comes while serving a page instead of redirecting' do
    PluginRoutes.add_anonymous_hook('admin_before_load', lambda { |_args|
      CamaleonCms::PostType.find(post_type.id).set_option(option, 'Object')
    }, 'decorator-before-load')
    sign_in_as(create(:user_admin, site: @site), site: @site)

    expect { get '/admin/dashboard' }.to raise_error(ActiveRecord::RecordInvalid, /cama_post_decorator_class/)
  ensure
    PluginRoutes.remove_anonymous_hook('admin_before_load', 'decorator-before-load')
  end

  # A value stored without passing the check (before it existed, or a removed plugin's decorator) is
  # ignored at read; it is no reason to refuse the next save of the post type's settings.
  it 'saves a post type whose stored decorator option the check would refuse' do
    meta = post_type.metas.find_by!(key: '_default')
    meta.update!(value: JSON.parse(meta.value).merge(option => 'Object').to_json)
    sign_in_as(create(:user_admin, site: @site), site: @site)

    patch "/admin/settings/post_types/#{post_type.id}",
          params: { post_type: { name: 'Renamed posts', slug: post_type.slug }, meta: { has_tags: '1' } }

    expect(response).to redirect_to('/admin/settings/post_types')
    stored = CamaleonCms::PostType.find(post_type.id)
    expect(stored.name).to eq('Renamed posts')
    expect(stored.get_option(option)).to eq('Object')
  end

  it 'renders a post whose post type stores a decorator option the check would refuse' do
    meta = post_type.metas.find_by!(key: '_default')
    meta.update!(value: JSON.parse(meta.value).merge(option => 'Object').to_json)
    warnings = []
    allow(Rails.logger).to receive(:warn) { |message| warnings << message }

    get @post.the_url(as_path: true), headers: { 'HTTP_HOST' => @site.slug }

    expect(response).to have_http_status(:ok)
    expect(warnings.grep(/cama_post_decorator_class/).size).to eq(1)
  end

  it 'stores a post decorator' do
    hook_storing_decorator('CamaleonCms::PostDecorator')
    sign_in_as(settings_manager, site: @site)

    save_post_type

    expect(response).to redirect_to('/admin/settings/post_types')
    expect(CamaleonCms::PostType.find(post_type.id).get_option(option)).to eq('CamaleonCms::PostDecorator')
  end
end
