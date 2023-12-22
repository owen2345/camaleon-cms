# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SiteDecorator, type: :model do
  %i[post_type post site user].each do |klass|
    describe 'Marshal compatibility' do
      let!(:object) { create(klass) }
      let!(:decorator) { object.decorate }

      it 'Marshal dumps and loads the same object' do
        dump = Marshal.dump(decorator)
        recovered_decorator = Marshal.load(dump)
        expect(recovered_decorator).to eql(decorator)
        expect(recovered_decorator.object).to eql(object)
      end

      it 'Writes to the Rails cache' do
        Rails.cache.write(klass, decorator)
        cache_result = Rails.cache.read klass
        expect(cache_result.object).to eql(object)
      end
    end
  end
end
