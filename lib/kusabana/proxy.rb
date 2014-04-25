#coding: utf-8
require 'memcached'
require 'em-proxy'
require 'uuid'
require 'http/parser'
require 'ltsv-logger'

module Kusabana
  class Proxy
    attr_accessor :logger, :cache
    attr_reader :rules, :config
    def initialize(rules, config)
      @rules = rules
      @config = config
      @cache = Memcached.new(@config['cache']['url'])

      LTSV::Logger.open(config['proxy']['output'] || STDOUT)
      @logger = LTSV.logger
    end

    def start
      Process.daemon(true, true) if @config['proxy']['daemonize']
      EM.epoll

      EM.run do
        trap("TERM") { stop }
        trap("INT") { stop }

        EM::start_server(@config['proxy']['host'], @config['proxy']['port'], Kusabana::Connection, @config) do |conn|
          conn.proxy = self
        end
        open(@config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid } if @config['proxy']['daemonize']
      end
    end

    def stop
      EM.stop
    end
  end
end
