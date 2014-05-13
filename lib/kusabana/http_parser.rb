# coding: UTF-8
require 'http/parser'
require 'uuid'

module Kusabana
  class RequestParser < Http::Parser
    def initialize(env, conn)
      @env = env
      @conn = conn
      @buffer = ''
      @body = ''
      self.on_body = on_parse_request_body
      self.on_message_complete = on_parse_request
    end
    
    def <<(data)
      @buffer << data
      super
    end

    def cache_key(body)
      "#{http_method}::#{request_url}::#{body.hash}"
    end

    def on_parse_request_body
      ->(chunk) do
        @body << chunk
      end
    end

    def on_parse_request
      -> do
        session_name = UUID.generate :compact
        @env.sessions[session_name] = {start: Time.new}
        body, match = -> do
          @env.rules.each do |rule|
            if rule.match(http_method, request_url)
              @env.sessions[session_name].merge!(rule: rule, cache: true)
              return [rule.modify(@body), true]
            end
          end
          [@body, false]
        end.call

        cache_key = cache_key(body)
        @env.logger.req(method: http_method, path: request_url, match: match, session: session_name, orig_query: @body, mod_query: body)

        relay = -> do
          res_parser = Kusabana::ResponseParser.new(@env, session_name)
          @env.sessions[session_name].merge!(cache_key: cache_key, res_parser: res_parser, path: request_url, method: http_method)
          s = @conn.server session_name
          s.send_data ((match)? @buffer.gsub(/\r\n\r\n.+/m, "\r\n\r\n#{body}"): @buffer)
        end
        
        if match
          EM.defer -> do
            @env.cache.get_or_nil(cache_key)
          end, ->(res) do
            if res
              @env.logger.res(method: http_method, path: request_url, cache: 'use', session: session_name, took: Time.new - @env.sessions[session_name][:start], key: cache_key)
              @env.sessions.delete(session_name)
              @conn.send_data res
            else
              relay.call
            end
          end
        else
          relay.call
        end
      end
    end

  end

  class ResponseParser < Http::Parser
    def initialize(env, session_name)
      super
      @env = env
      @buffer = ''
      self.on_message_complete = on_parse_response(session_name)
    end

    def <<(data)
      @buffer << data
      super
    end

    def on_parse_response(session_name)
      -> do
        caching = 'no'
        s = @env.sessions[session_name]
        log = {}
        s[:res_parser].status_code
        logging = -> { @env.logger.res(log.merge(method: s[:method], path: s[:path], cache: caching, session: session_name, took: Time.new - s[:start], key: s[:cache_key], status: s[:res_parser].status_code)) }
        if s[:cache] && s[:res_parser].status_code == 200
          EM.defer -> do
            @env.cache.set(s[:cache_key], @buffer, s[:rule].expired)
          end, ->(store) do
            if store
              caching = 'store'
              log[:expire] = s[:rule].expired
            else
              caching = 'error'
            end
            logging.call
          end
        else
          logging.call
        end
      end
    end
  end
end
