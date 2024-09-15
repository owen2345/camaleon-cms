# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'New folder request', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:authorize!)
  end

  context 'when the folder path is valid' do
    it 'creates the new folder' do
      post '/admin/media/actions', params: { folder: '/test2', media_action: 'new_folder' }

      expect(Dir).to exist(File.join(current_site.upload_directory, '/test2'))
    end
  end

  context 'when the folder path is invalid' do
    it 'returns invalid file path error' do
      post '/admin/media/actions', params: { folder: '/../test3', media_action: 'new_folder' }

      expect(Dir).not_to exist(File.join(current_site.upload_directory, '/../test3'))

      expect(response.body).to include('Invalid folder path')
    end
  end
end
