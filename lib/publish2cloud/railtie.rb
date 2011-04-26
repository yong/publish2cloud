require 'publish2cloud'
require 'rails'

module Publish2Cloud
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'publish2cloud/tasks.rb'
    end
  end
end
