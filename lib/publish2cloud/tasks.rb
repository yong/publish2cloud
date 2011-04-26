require File.expand_path(File.join(File.dirname(__FILE__), '..', 'publish2cloud', 'publish2cloud'))

namespace :p2c do
  desc "Publish2Cloud"
  task :push do
    p2c = Publish2Cloud::Publisher.new("", "", "", "")
  end
end
