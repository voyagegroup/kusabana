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
      @cache = Memcached.new(@config['cache']['url'])
      @sessions = {}

      @req_parser = HTTP::Parser.new
      @req_buffer = ''
      @req_body = ''

      @res_parser = HTTP::Parser.new
      @res_buffer = ''

      LTSV::Logger.open(config['proxy']['output'] || STDOUT)
      @logger = LTSV.logger
    end

    def start
      if @config['proxy']['daemonize']
        Process.daemon(true, true)
        open(@config['proxy']['pid'] || 'kusabana.pid', 'w') {|f| f << Process.pid }
      end
      EM.epoll

      EM.run do
        trap("TERM") { stop }
        trap("INT") { stop }

        EM::start_server(@config['proxy']['host'], @config['proxy']['port'], EM::ProxyServer::Connection, @config) do |conn|

          # Request
          @req_parser.on_body = on_parse_request_body
          @req_parser.on_message_complete = on_parse_request(conn)
          conn.on_data(&on_data)

          # Response
          @res_parser.on_message_complete = on_parse_response
          conn.on_response(&on_response)
        end
      end
    end

    def stop
      EM.stop
    end

    # Callbacks
    private
    def on_data
      -> (data) do
        @req_buffer << data
        @req_parser << data
        :async
      end
    end

    def on_parse_request_body
      -> (chunk) do
        @req_body << chunk
      end
    end

    def on_parse_request(conn)
      -> do
        session = UUID.generate :compact
        @sessions[session] = {start: Time.new}
        req = -> do
          @rules.each do |rule|
            if rule.match(@req_parser.http_method,@req_parser.request_url)
              @logger.info(type: 'req', method: @req_parser.http_method, path: @req_parser.request_url, match: true, session: session)
              modified, hash = rule.modify(@req_body)
              if res = @cache.get_or_nil(hash)
                conn.send_data res
                return nil
              else
                @sessions[session].merge!(rule: rule, hash: hash)
                return @req_buffer.gsub(/\r\n\r\n.+/m, "\r\n\r\n#{modified}")
              end
            end
          end
          @logger.info(type: 'req', method: @req_parser.http_method, path: @req_parser.request_url, match: false, session: session)
          @req_buffer
        end
        
        if req = req.call
          s = conn.server session, :host => @config['es']['host'], :port => @config['es']['port']
          s.send_data req
        else
          @logger.info(type: 'res', method: @req_parser.http_method, path: @req_parser.request_url, cache: 'use', session: session, took: Time.new - @sessions[session][:start])
        end
        @req_buffer.clear
        @req_body.clear
      end
    end

    def on_parse_response
      -> do
        caching = 'no'
        s = @sessions[@session]
        if hash = s[:hash]
          @cache.set(hash, @res_buffer, s[:rule].expired)
          caching = 'store'
        end
        @logger.info(type: 'res', method: @req_parser.http_method, path: @req_parser.request_url, cache: caching, session: @session, took: Time.new - s[:start])
        @sessions.delete(@session)
        @res_buffer.clear
      end
    end

    def on_response
      -> (backend, resp) do
        @session = backend
        @res_buffer << resp
        @res_parser << resp
        resp
      end
    end
  end
end
