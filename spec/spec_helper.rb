#coding: utf-8

require 'kusabana'
require 'webmock/rspec'
require 'yaml'
require 'uuid'

def config
  YAML.load_file("./spec/config.yml")
end

RSpec.configure do |c|
  c.before(:each) { allow(EM).to receive(:defer) {|op, cb| cb.call(op.call) } }
end
