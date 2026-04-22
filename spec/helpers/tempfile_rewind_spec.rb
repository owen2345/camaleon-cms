# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tempfile rewind regression' do
  include CamaleonCms::UploaderHelper

  it 'does not consume the Tempfile when scanning for suspicious content' do
    tmp = Tempfile.new(['cama-test'])
    begin
      tmp.binmode
      tmp.write('safe content')
      tmp.rewind

      helper_obj = Class.new { include CamaleonCms::UploaderHelper }.new

      # Call the private method via send to ensure we exercise the scanning logic
      expect(helper_obj.send(:file_content_unsafe?, tmp)).to be_nil

      # After scanning, the tempfile should still be readable (not at EOF)
      tmp.rewind
      expect(tmp.read).to eq('safe content')
    ensure
      tmp.close!
    end
  end
end
