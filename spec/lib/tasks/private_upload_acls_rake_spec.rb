# frozen_string_literal: true
require 'rake'

RSpec.describe 'private_upload_acls Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    # Another rake spec's load_tasks may already have registered this task; clear it first so this
    # file's load registers its action exactly once (invoking twice would double the sweep).
    task_name = 'camaleon_cms:repair_private_upload_acls'
    Rake::Task[task_name].clear if Rake::Task.task_defined?(task_name)
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:repair_private_upload_acls'].clear
  end

  describe 'camaleon_cms:repair_private_upload_acls' do
    let(:task) { Rake::Task['camaleon_cms:repair_private_upload_acls'] }
    let(:site) { CamaleonCms::Site.first }
    let(:bucket) { instance_double(Aws::S3::Bucket) }
    let(:object_acl) { instance_double(Aws::S3::ObjectAcl) }
    let(:s3_object) { instance_double(Aws::S3::ObjectSummary, acl: object_acl) }

    before do
      task.reenable
      allow_any_instance_of(CamaleonCmsAwsUploader).to receive(:bucket).and_return(bucket)
    end

    it 're-ACLs objects under the private prefix for AWS-backed sites' do
      site.set_option('filesystem_type', 'aws')
      allow(bucket).to receive(:objects).with(prefix: 'private/').and_return([s3_object])
      expect(object_acl).to receive(:put).with(acl: 'private')

      expect { task.invoke }.to output(/re-ACLed 1 object\(s\) across 1 AWS site\(s\)/).to_stdout
    end

    it 'skips sites not on AWS storage' do
      expect(bucket).not_to receive(:objects)

      expect { task.invoke }.to output(/across 0 AWS site\(s\)/).to_stdout
    end
  end
end
