# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Download private file requests', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:current_site).and_return(current_site)
  end

  context 'when the file path is valid and file exists' do
    before do
      allow_any_instance_of(CamaleonCmsLocalUploader).to receive(:fetch_file).and_return('some_file')

      allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:send_file)
      allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:default_render)
    end

    it 'allows the file to be downloaded' do
      expect_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:send_file).with('some_file', disposition: 'inline')

      get '/admin/media/download_private_file', params: { file: 'some_file' }
    end
  end

  context 'when file path is invalid' do
    it 'returns invalid file path error' do
      get '/admin/media/download_private_file', params: { file: './../../../../../etc/passwd' }

      expect(response.body).to include('Invalid file path')
    end
  end

  context 'when the file is not found' do
    it 'returns file not found error' do
      get '/admin/media/download_private_file', params: { file: 'passwd' }

      expect(response.body).to include('File not found')
    end
  end
end
