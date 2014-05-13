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
          EM::PeriodicTimer.new(300) { @env.logger.interval }
          open(@env.config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid } if @env.config['proxy']['daemonize']
        end
      rescue HTTP::Parser::Error => e
        @env.logger.error(e.to_s)
        @env.logger.error(e.backtrace)
        @env.sessions.clear
        start
      end
    end

    def stop
      EM.next_tick { EM.stop }
    end
  end
end
