
Gem::Specification.new do |s|
  s.name = %q{publish2cloud}
  s.version = "0.1.1"

  s.authors = ["Xue Yong Zhi"]
  s.date = %q{2011-04-25}
  s.email = ["yong@intridea.com"]
  s.files = Dir['lib/**/*.rb'] + Dir['lib/**/*.rake']
  s.summary = %q{publish2cloud}
  s.homepage = "http://github.com/yong/publish2cloud"
  s.add_dependency(%q<ruby-hmac>)
  s.add_dependency(%q<right_aws>)
  s.add_dependency(%q<nokogiri>)
end
