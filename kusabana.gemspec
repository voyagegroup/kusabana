# encoding: utf-8

$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = "kusabana"
  s.version = "0.0.1"
  s.platform = Gem::Platform::RUBY
  s.authors = ["Satoshi Amemiya"]
  s.email = ["satoshi_amemiya@voyagegroup.com"]
  s.summary = %q{Test implemention cache proxy between kibana and ElasticSearch}
  s.description = s.summary

  s.add_dependency 'memcached', '~> 1.7.2'
  s.add_dependency 'em-proxy', '~> 0.1.8'
  s.add_dependency 'oj', '~> 2.7.3'
  s.add_dependency 'http_parser.rb', '~> 0.6.0'
  s.add_dependency 'uuid'

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
