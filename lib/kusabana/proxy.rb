#coding: utf-8
require 'memcached'
require 'em-proxy'
require 'uuid'
require 'http/parser'
require 'ltsv-logger'

module Kusabana
  class Proxy
    def initialize(rules, config)
      @rules = rules
      @config = config

      @cache = Kusabana::Cache.new(@config['cache']['url'])
      LTSV::Logger.open(config['proxy']['output'] || STDOUT)
      @logger = LTSV.logger
    end

    def start
      Process.daemon(true, true) if @config['proxy']['daemonize']
      EM.epoll

      EM.run do
        trap("TERM") { stop }
        trap("INT") { stop }

        option = {cache: @cache, logger: @logger, rules: @rules, es: @config['es']}
        EM::start_server(@config['proxy']['host'], @config['proxy']['port'], Kusabana::Connection, option)
        open(@config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid } if @config['proxy']['daemonize']
      end
    end

    def stop
      EM.stop
    end
  end
end
