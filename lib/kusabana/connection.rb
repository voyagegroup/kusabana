# coding: UTF-8
require 'em-proxy'

module Kusabana
  class Connection < EM::ProxyServer::Connection
    def initialize(option)
      @env = option[:env]
      @on_data = on_data
      @on_response = on_response
      @on_finish = on_finish
      comm_inactivity_timeout = @env.config['proxy']['timeout']
      super
    end

    def relay(session_name, data)
      @env.sessions[session_name][:res_parser] = Kusabana::ResponseParser.new(@env, session_name)
      s = server session_name
      s.send_data data
    end

    def server(session_name)
      s = super session_name, :host => @env.config['es']['remote']['host'], :port => @env.config['es']['remote']['port']
      s.comm_inactivity_timeout = @env.config['proxy']['timeout']
      s
    end

    # Callbacks
    private
    def on_data
      ->(data) do
        req_parser = Kusabana::RequestParser.new(@env, self)
        req_parser << data
        :async
      end
    end

    def on_response
      ->(backend, resp) do
        s = @env.sessions[backend]
        s[:res_parser] << resp
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
