require File.expand_path(File.join(File.dirname(__FILE__), '..', 'publish2cloud', 'publish2cloud'))

PUBLISH2CLOUD_CONFIG_FILE = Rails.root.join('config', 'publish2cloud.rb')

namespace :p2c do
  desc "Publish2Cloud"
  task :push do
    
    require PUBLISH2CLOUD_CONFIG_FILE
    p2c = Publish2Cloud::Publisher.new(P2C_S3_ACCESS_KEY_ID, P2C_S3_SECRET_ACCESS_KEY, P2C_S3_BUCKET, P2C_CF_DISTRIBUTION_ID)
  end
end
