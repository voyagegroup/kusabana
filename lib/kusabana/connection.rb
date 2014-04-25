require 'uuid'

module Kusabana
  class Connection < EM::ProxyServer::Connection
    attr_accessor :proxy
    def initialize(options)
      @on_data = on_data
      @on_response = on_response

      @req_parser = HTTP::Parser.new
      @req_buffer = ''
      @req_body = ''
      @req_parser.on_body = on_parse_request_body
      @req_parser.on_message_complete = on_parse_request
      @sessions = {}

      super(options)
    end

    # Callbacks
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
        uuid = UUID.generate :compact
        res_parser = HTTP::Parser.new
        res_parser.on_message_complete = on_parse_response(uuid)
        res_buffer = ''
        @sessions[uuid] = {start: Time.new, res_parser: res_parser, res_buffer: res_buffer}
        req = -> do
          @proxy.rules.each do |rule|
            if rule.match(@req_parser.http_method,@req_parser.request_url)
              @proxy.logger.info(type: 'req', method: @req_parser.http_method, path: @req_parser.request_url, match: true, session: uuid)
              modified, hash = rule.modify(@req_body)
              if res = @proxy.cache.get_or_nil(hash)
                send_data res
                return nil
              else
                @sessions[uuid].merge!(rule: rule, hash: hash)
                return @req_buffer.gsub(/\r\n\r\n.+/m, "\r\n\r\n#{modified}")
              end
            end
          end
          @proxy.logger.info(type: 'req', method: @req_parser.http_method, path: @req_parser.request_url, match: false, session: uuid)
          @req_buffer
        end
        
        if req = req.call
          s = server uuid, :host => @proxy.config['es']['host'], :port => @proxy.config['es']['port']
          s.send_data req
        else
          @proxy.logger.info(type: 'res', method: @req_parser.http_method, path: @req_parser.request_url, cache: 'use', session: uuid, took: Time.new - @sessions[uuid][:start])
          @sessions.delete(uuid)
        end
        @req_buffer.clear
        @req_body.clear
      end
    end

    def on_parse_response(uuid)
      -> do
        caching = 'no'
        s = @sessions[uuid]
        if hash = s[:hash]
          @proxy.cache.set(hash, s[:res_buffer], s[:rule].expired)
          caching = 'store'
        end
        @proxy.logger.info(type: 'res', method: @req_parser.http_method, path: @req_parser.request_url, cache: caching, session: uuid, took: Time.new - s[:start])
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
