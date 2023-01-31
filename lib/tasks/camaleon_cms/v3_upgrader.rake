# frozen_string_literal: true

namespace :camaleon_cms do
  namespace :v3_upgrader do
    desc 'Upgrade DB content for CamaleonCMS V3'
    task run: :environment do
      CamaleonCms::Site.transaction do
        CamaleonCms::V3Migration::StiTaxonomiesConverter.call
        CamaleonCms::V3Migration::StiPostsConverter.call
        CamaleonCms::V3Migration::PolymorphicMetasConverter.call
        CamaleonCms::V3Migration::FieldsGenerator.call
      end
    end

    desc 'Revert upgraded DB content for CamaleonCMS V3'
    task revert: :environment do
      CamaleonCms::Site.transaction do
        CamaleonCms::V3Migration::StiTaxonomiesConverter.revert
        CamaleonCms::V3Migration::StiPostsConverter.revert
        CamaleonCms::V3Migration::PolymorphicMetasConverter.revert
        CamaleonCms::V3Migration::FieldsGenerator.revert
      end
    end
  end
end
