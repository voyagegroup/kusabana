#coding: utf-8
require 'memcached'
require 'em-proxy'
require 'uuid'
require 'http/parser'

module Kusabana
  class Proxy
    def initialize(rules, config)
      @rules = rules
      @config = config

      @cache = Kusabana::Cache.new(@config['cache']['url'])
      @logger = Kusabana::Logger.new(config['proxy']['output'] || STDOUT, 7, es: @config['es']['output'])
    end

    def start
      begin
        Process.daemon(true, true) if @config['proxy']['daemonize']
        EM.epoll

        EM.run do
          trap("TERM") { stop }
          trap("INT") { stop }

          option = {cache: @cache, logger: @logger, rules: @rules, es: @config['es']['remote']}
          EM::start_server(@config['proxy']['host'], @config['proxy']['port'], Kusabana::Connection, option)
          EM::PeriodicTimer.new(30) { @logger.stat }
          open(@config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid } if @config['proxy']['daemonize']
        end
      rescue => e
        @logger.error(e.to_s)
        @logger.error(e.backtrace)
      end
    end

    def stop
      EM.stop
    end
  end
end
