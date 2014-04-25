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
        req = -> do
          @rules.each do |rule|
            if rule.match(@req_parser.http_method,@req_parser.request_url)
              @logger.info(type: 'req', method: @req_parser.http_method, path: @req_parser.request_url, match: true, session: session_name)
              modified, hash = rule.modify(@req_body)
              if res = @cache.get_or_nil(hash)
                send_data res
                return nil
              else
                @sessions[session_name].merge!(rule: rule, hash: hash)
                return @req_buffer.gsub(/\r\n\r\n.+/m, "\r\n\r\n#{modified}")
              end
            end
          end
          @logger.info(type: 'req', method: @req_parser.http_method, path: @req_parser.request_url, match: false, session: session_name)
          @req_buffer
        end
        
        if req = req.call
          s = server session_name
          s.send_data req
        else
          @logger.info(type: 'res', method: @req_parser.http_method, path: @req_parser.request_url, cache: 'use', session: session_name, took: Time.new - @sessions[session_name][:start])
          @sessions.delete(session_name)
        end
        @req_buffer.clear
        @req_body.clear
      end
    end

    def on_parse_response(session_name)
      -> do
        caching = 'no'
        s = @sessions[session_name]
        if hash = s[:hash]
          @cache.set(hash, s[:res_buffer], s[:rule].expired)
          caching = 'store'
        end
        @logger.info(type: 'res', method: @req_parser.http_method, path: @req_parser.request_url, cache: caching, session: session_name, took: Time.new - s[:start])
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
