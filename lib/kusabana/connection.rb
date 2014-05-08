require 'uuid'

module Kusabana
  class Connection < EM::ProxyServer::Connection
    def initialize(option)
      @cache = option[:cache]
      @logger = option[:logger]
      @rules = option[:rules]
      @es = option[:es]

      @on_data = on_data
      @on_response = on_response

      @req_parser = HTTP::Parser.new
      @req_buffer = ''
      @req_body = ''
      @req_parser.on_body = on_parse_request_body
      @req_parser.on_message_complete = on_parse_request
      @sessions = {}

      super(option)
    end

    def server(session_name)
      super session_name, :host => @es['host'], :port => @es['port']
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

    def on_parse_request
      -> do
        session_name = UUID.generate :compact
        res_parser = HTTP::Parser.new
        res_parser.on_message_complete = on_parse_response(session_name)
        res_buffer = ''
        @sessions[session_name] = {start: Time.new, res_parser: res_parser, res_buffer: res_buffer}

        body, match = -> do
          @rules.each do |rule|
            if rule.match(@req_parser.http_method,@req_parser.request_url)
              @sessions[session_name].merge!(rule: rule, cache: true)
              return [rule.modify(@req_body), true]
            end
          end
          [@req_body, false]
        end.call

        cache_key = @req_parser.cache_key(body)
        @logger.req(method: @req_parser.http_method, path: @req_parser.request_url, match: match, session: session_name)
        
        if match && res = @cache.get_or_nil(cache_key)
          @logger.res(method: @req_parser.http_method, path: @req_parser.request_url, cache: 'use', session: session_name, took: Time.new - @sessions[session_name][:start], key: cache_key)
          @sessions.delete(session_name)
          send_data res
          return
        end

        @sessions[session_name][:cache_key] = cache_key
        s = server session_name
        s.send_data ((match)? @req_buffer.gsub(/\r\n\r\n.+/m, "\r\n\r\n#{body}"): @req_buffer)
        @req_buffer.clear
        @req_body.clear
      end
    end

    def on_parse_response(session_name)
      -> do
        caching = 'no'
        s = @sessions[session_name]
        if s[:cache]
          store = @cache.set(s[:cache_key], s[:res_buffer], s[:rule].expired)
          caching = (store)? 'store': 'error'
        end
        @logger.res(method: @req_parser.http_method, path: @req_parser.request_url, cache: caching, session: session_name, took: Time.new - s[:start], key: s[:cache_key])
        send_data s[:res_buffer]
      end
    end

    def on_response
      -> (backend, resp) do
        s = @sessions[backend]
        s[:res_buffer] << resp
        s[:res_parser] << resp
        nil
      end
    end
  end
end
