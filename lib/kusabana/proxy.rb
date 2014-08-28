#coding: utf-8
require 'eventmachine'

module Kusabana
  class Proxy
    attr_reader :rules, :global_rule, :config

    def initialize(config)
      @config = config
      @global_rule = nil
      @rules = {}
    end

    def set_global_rule(rule)
      @global_rule = rule
    end

    def set_rule(path, rule)
      @rules[path] = rule
    end

    def start
      env = Kusabana::Environment.new(self)
      begin
        Process.daemon(true, true) if env.config['proxy']['daemonize']
        EM.epoll

        EM.run do
          trap("TERM") { stop }
          trap("INT") { stop }

          EM::start_server(env.config['proxy']['host'], env.config['proxy']['port'], Kusabana::Connection, env: env)
          if env.logger.es
            EM.add_timer(300) { env.logger.interval }
          end
          open(env.config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid } if env.config['proxy']['daemonize']
        end
      rescue => e
        env.logger.error(e.class)
        env.logger.error(e.to_s)
        env.logger.error(e.backtrace)
      end
    end

    def stop
      EM.stop
    end
  end
end
