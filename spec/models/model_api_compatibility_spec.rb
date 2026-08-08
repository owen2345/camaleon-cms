# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Model API compatibility', type: :model do
  init_site

  let(:site) { Cama::Site.first }

  describe 'Media.find_by_key' do
    let!(:folder) { site.public_media.create!(name: 'compat', folder_path: '/', is_folder: true) }

    it 'returns the same records as by_key' do
      # rubocop:disable Rails/DynamicFindBy
      legacy = site.public_media.find_by_key('/compat')
      # rubocop:enable Rails/DynamicFindBy

      expect(legacy).to eq(site.public_media.by_key('/compat'))
      expect(legacy).to contain_exactly(folder)
    end
  end
end
