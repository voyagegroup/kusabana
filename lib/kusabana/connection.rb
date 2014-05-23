# coding: UTF-8
require 'em-proxy'

module Kusabana
  class Connection < EM::ProxyServer::Connection
    def initialize(option)
      @env = option[:env]
      @on_data = on_data
      @on_response = on_response
      @on_finish = on_finish
      create_session
      comm_inactivity_timeout = @env.config['proxy']['timeout']
      super
    end

    def create_session
      @req_parser = Kusabana::RequestParser.new(@env, self)
    end

    def relay(session_name, data)
      @env.sessions[session_name][:res_parser] = Kusabana::ResponseParser.new(@env, session_name)
      s = server session_name
      s.send_data data
    end

    def server(session_name)
      r = @env.remote(session_name)
      s = super session_name, :host => r['host'], :port => r['port']
      s.comm_inactivity_timeout = @env.config['proxy']['timeout']
      s
    end

    # Callbacks
    private
    def on_data
      ->(data) do
        unless @req_parser << data
          EM.next_tick { close_connection_after_writing }
        end
        :async
      end
    end

    def on_response
      ->(backend, resp) do
        if s = @env.sessions[backend]
          unless s[:res_parser] << resp
            EM.next_tick { close_connection_after_writing }
          end
        end
        resp
      end
    end

    def on_finish
      ->(backend) do
        @env.sessions.delete(backend)
      end
    end
  end
end
