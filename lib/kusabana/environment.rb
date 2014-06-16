#coding: utf-8

module Kusabana
  class Environment
    attr_reader :rules, :global_rule, :logger, :cache, :es_source, :es_output, :config
    attr_reader :sessions
    def initialize(proxy)
      @config = proxy.config
      @rules = proxy.rules
      @global_rule = proxy.global_rule
      @cache = Kusabana::Cache.new(@config['cache']['url'])
      @logger = Kusabana::Logger.new(@config['proxy']['output'] || STDOUT, 7, self)
      @sessions = {}
    end

    def remote(session_name)
      path = @sessions[session_name][:path]
      @config['es']['remotes'].each do |remote|
        if path.start_with?(remote['path'])
          return remote
        end
      end
      @config['es']['remotes'][0]
    end
  end
end
