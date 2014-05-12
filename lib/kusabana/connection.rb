# coding: UTF-8
require 'uuid'

module Kusabana
  class Connection < EM::ProxyServer::Connection
    def initialize(option)
      @env = option[:env]
      @on_data = on_data
      @on_response = on_response
      super
    end

    def server(session_name)
      super session_name, :host => @env.config['es']['remote']['host'], :port => @env.config['es']['remote']['port']
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
  end
end
