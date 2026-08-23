# frozen_string_literal: true

RSpec.describe Plugins::VisibilityPost::VisibilityPostHelper, type: :helper do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.first }

  before do
    # Include required helpers so signin? and current_site work
    helper.extend(CamaleonCms::SessionHelper)
    allow(helper).to receive(:current_site).and_return(current_site)
  end

  describe '#plugin_visibility_filter_post' do
    let(:base_scope) { CamaleonCms::Post.where(post_type_id: post_type.id) }

    context 'when user is not signed in' do
      before { allow(helper).to receive(:signin?).and_return(false) }

      it 'excludes private posts' do
        args = { active_record: base_scope }
        helper.plugin_visibility_filter_post(args)

        sql = args[:active_record].to_sql
        expect(sql).to include("visibility != 'private'")
        expect(sql).not_to include('LIKE')
      end
    end

    context 'when user is signed in' do
      before do
        allow(helper).to receive(:signin?).and_return(true)
        allow(current_site).to receive(:visitor_role).and_return('post_editor')
      end

      it 'parameterizes the visitor_role in the query' do
        args = { active_record: base_scope }
        helper.plugin_visibility_filter_post(args)

        # The role value should be bound as a parameter, not interpolated into SQL
        sql = args[:active_record].to_sql
        expect(sql).to include('LIKE')
        expect(sql).to include('%,post_editor,%')
      end

      it 'does not allow SQL injection through visitor_role' do
        malicious_role = "admin' OR '1'='1"
        allow(current_site).to receive(:visitor_role).and_return(malicious_role)

        args = { active_record: base_scope }
        helper.plugin_visibility_filter_post(args)

        sql = args[:active_record].to_sql
        # The malicious string should be escaped/quoted, not raw SQL
        expect(sql).not_to include("OR '1'='1'")
      end
    end
  end
end
