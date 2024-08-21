# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCmsLocalUploader do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:uploader) { described_class.new(current_site: current_site) }

  describe '#delete_folder' do
    it 'returns an error' do
      expect(uploader.delete_folder('../tmp')).to eql(error: 'Invalid folder path')
    end
  end

  describe '#delete_file' do
    it 'returns an error' do
      expect(uploader.delete_file('../test.rb')).to eql(error: 'Invalid file path')
    end
  end
end
