#coding: utf-8
require 'elasticsearch'

module Kusabana
  class Environment
    attr_reader :rules, :logger, :cache, :es_source, :es_output, :config
    attr_reader :sessions
    def initialize(rules, config)
      @config = config
      @rules = rules
      @cache = Kusabana::Cache.new(config['cache']['url'])
      @logger = Kusabana::Logger.new(config['proxy']['output'] || STDOUT, 7, self)
      @sessions = {}
    end
  end
end
