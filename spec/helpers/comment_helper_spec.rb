# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::CommentHelper, type: :helper do
  include described_class

  let(:author) do
    double(the_admin_profile_url: '/admin/profile', the_avatar: '/avatar.png', the_name: 'Author')
  end
  let(:children) { double(decorate: []) }
  let(:comment) do
    double(
      the_author: author,
      the_created_at: 'today',
      approved: 'approved',
      content: 'body',
      id: 7,
      children: children
    )
  end
  let(:comments) { double(decorate: [comment]) }

  before do
    allow(helper).to receive_messages(sanitize: 'body', t: 'txt', url_for: '/toggle')
    allow(helper).to receive(:link_to) { |_arg = nil, *_args, &blk| blk ? blk.call : 'link' }
  end

  it 'uses explicit post_id for reply links' do
    expect(helper).to receive(:cama_admin_post_comment_answer_path).with(42, 7)
    helper.cama_comments_render_html(comments, 42)
  end

  it 'falls back to controller @post when post_id is omitted' do
    helper.controller.instance_variable_set(:@post, double(id: 33))
    expect(helper).to receive(:cama_admin_post_comment_answer_path).with(33, 7)
    helper.cama_comments_render_html(comments)
  end
end
