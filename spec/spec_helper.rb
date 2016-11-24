require 'shared_helper'

require 'rspec/autorun'
require 'capybara/rspec'
require 'shoulda/matchers'
require "paperclip/matchers"


Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec

    with.library :rails
  end
end



RSpec.configure do |config|
  config.include Devise::TestHelpers, type: :controller
  config.include Paperclip::Shoulda::Matchers

  config.infer_base_class_for_anonymous_controllers = false

  config.after(:suite) do
    FileUtils.rm_rf(Dir["#{Rails.root}/spec/test_files/"])
  end
end
