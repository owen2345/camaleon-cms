# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::PostUniqValidator, type: :model do
  init_site

  let(:post_type) { create(:post_type, slug: 'test-pt', site: @site) }

  def validate_post(post)
    validator = described_class.new
    validator.validate(post)
    post.errors[:base]
  end

  describe '#validate' do
    context 'when post is a draft' do
      it 'skips validation' do
        post = create(:post, post_type: post_type, slug: 'test-slug', status: 'draft')
        expect(validate_post(post)).to be_empty
      end
    end

    context 'when post has unique slug' do
      it 'passes validation' do
        post = create(:post, post_type: post_type, slug: 'unique-slug')
        expect(validate_post(post)).to be_empty
      end
    end

    context 'with SQL injection attempts in slug' do
      it 'does not execute injected SQL - boolean based' do
        create(:post, post_type: post_type, slug: 'legit-slug', status: 'published')
        post = create(:post, post_type: post_type, slug: "' OR '1'='1")

        expect { validate_post(post) }.not_to raise_error
        expect(validate_post(post)).to be_empty
      end

      it 'handles SQL injection with UNION attempt' do
        post = create(:post, post_type: post_type, slug: "test' UNION SELECT")

        expect { validate_post(post) }.not_to raise_error
        result = validate_post(post)
        expect(result).to be_empty.or contain_exactly(match(/requires_different_slug/))
      end

      it 'handles malicious slug with comment injection' do
        post = create(:post, post_type: post_type, slug: "test'--")

        expect { validate_post(post) }.not_to raise_error
        result = validate_post(post)
        expect(result).to be_empty.or contain_exactly(match(/requires_different_slug/))
      end

      it 'handles slug with semicolon and multiple statements' do
        post = create(:post, post_type: post_type, slug: "test'; DROP TABLE posts; --")

        expect { validate_post(post) }.not_to raise_error
        result = validate_post(post)
        expect(result).to be_empty.or contain_exactly(match(/requires_different_slug/))
      end
    end
  end
end
