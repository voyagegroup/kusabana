#coding: utf-8
require 'eventmachine'

module Kusabana
  class Proxy
    def initialize(rules, config)
      @env = Kusabana::Environment.new(rules, config)
    end

    def start
      begin
        Process.daemon(true, true) if @env.config['proxy']['daemonize']
        EM.epoll

        EM.run do
          trap("TERM") { stop }
          trap("INT") { stop }

          EM::start_server(@env.config['proxy']['host'], @env.config['proxy']['port'], Kusabana::Connection, env: @env)
          EM::PeriodicTimer.new(300) { @env.logger.stat }
          open(@env.config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid } if @env.config['proxy']['daemonize']
        end
      rescue => e
        @env.logger.error(e.to_s)
        @env.logger.error(e.backtrace)
      end
    end

    def stop
      EM.stop
    end
  end
end
