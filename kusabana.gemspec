# encoding: utf-8

require File.expand_path('../lib/kusabana/version', __FILE__)

Gem::Specification.new do |s|
  s.name = "kusabana"
  s.platform = Gem::Platform::RUBY
  s.authors = ["Satoshi Amemiya"]
  s.email = ["satoshi_amemiya@voyagegroup.com"]
  s.homepage = "http://voyagegroup.github.io/kusabana/"
  s.summary = %q{Kusabana is Proxy server with caching between Kibana and ElasticSearch}
  s.description = s.summary
  s.version = Kusabana::VERSION

  s.add_dependency 'rake', '~> 10.3'
  s.add_dependency 'memcached', '~> 1.7'
  s.add_dependency 'em-proxy', '~> 0.1'
  s.add_dependency 'oj', '~> 2.9'
  s.add_dependency 'http_parser.rb', '~> 0.6'
  s.add_dependency 'uuid', '~> 2.3'
  s.add_dependency 'elasticsearch', '~> 1.0'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'webmock', '~> 1.17'

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
