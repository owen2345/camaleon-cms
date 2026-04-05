CamaleonRecord is the base class of Camaleon CMS models. It inherits from `ActiveRecord::Base` and includes the `ActiveRecordExtras::Relation` module, which provides additional functionality to the models.

Authorization is handled by the `cancancan` gem, which allows you to define user permissions in an `Ability` class. 
You can specify what actions a user can perform on different models based on the UserRole ActiveRecord class.

When running rspec tests, please ensure that the RAILS_ENV environment variable is always set to test. The command should be executed as RAILS_ENV=test bundle exec rspec.

When providing 'Further Considerations,' always wait for my explicit confirmation before proceeding to any next steps or implementations.
