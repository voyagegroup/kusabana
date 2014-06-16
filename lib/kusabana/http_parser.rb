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
      begin
        super
        true
      rescue HTTP::Parser::Error => e
        @env.logger.error(e.class)
        @env.logger.error(e.to_s)
        @env.logger.error(e.backtrace)
        false
      end
    end

    def cache_key(body)
      "#{@env.config['cache']['key_prefix']}::#{http_method}::#{request_url}::#{body.hash}"
    end

    def on_parse_request_body
      ->(chunk) do
        @body << chunk
      end
    end

    def on_parse_request
      -> do
        @conn.create_session
        session_name = UUID.generate :compact
        @env.sessions[session_name] = {start: Time.new, path: request_url}
        remote = @env.remote(session_name)
        remote_path = request_url.gsub("#{remote['path']}/", '/')

        body, match = -> do
          if rules = @env.global_rule || @env.rules[remote['path']]
            rules.each do |rule|
              if rule.match(http_method, remote_path)
                @env.sessions[session_name].merge!(rule: rule, cache: true)
                return [rule.modify(@body), true]
              end
            end
          end
          [@body, false]
        end.call

        cache_key = cache_key(body)
        @env.logger.req(method: http_method, path: request_url, match: match, session: session_name, orig_query: @body, mod_query: body)
        
        if match
          EM.defer -> do
            @env.cache.get_or_nil(cache_key)
          end, ->(res) do
            if res
              @env.logger.res(method: http_method, path: request_url, cache: 'use', session: session_name, took: Time.new - @env.sessions[session_name][:start], key: cache_key)
              @env.sessions.delete(session_name)
              @conn.send_data res
            else
              @env.sessions[session_name].merge!(cache_key: cache_key, method: http_method)
              @conn.relay(session_name, @buffer.gsub(/ \/\S+?#{Regexp.escape remote_path} /, " #{remote_path} ").gsub(/\r\n\r\n.+/m, "\r\n\r\n#{body}"))
            end
          end
        else
          @env.sessions[session_name].merge!(cache_key: cache_key, method: http_method)
          @conn.relay(session_name, @buffer.gsub(/ \/\S+?#{Regexp.escape remote_path} /, " #{remote_path} "))
        end
      end
    end
  end

  class ResponseParser < Http::Parser
    def initialize(env, session_name)
      super
      @env = env
      @buffer = ''
      @session_name = session_name
      self.on_message_complete = on_parse_response
    end

    def <<(data)
      @buffer << data
      begin
        super
        true
      rescue HTTP::Parser::Error => e
        @env.logger.error(e.class)
        @env.logger.error(e.to_s)
        @env.logger.error(e.backtrace)
        @env.sessions.delete(@session_name)
        false
      end
    end

    def on_parse_response
      -> do
        caching = 'no'
        s = @env.sessions[@session_name]
        log = {}
        if s[:cache] && status_code == 200
          EM.defer -> do
            @env.cache.set(s[:cache_key], @buffer, s[:rule].expired)
          end, ->(store) do
            if store
              caching = 'store'
              log[:expire] = s[:rule].expired
            else
              caching = 'error'
            end
            @env.logger.res(log.merge(method: s[:method], path: s[:path], cache: caching, session: @session_name, took: Time.new - s[:start], key: s[:cache_key], status: status_code))
          end
        else
        @env.logger.res(log.merge(method: s[:method], path: s[:path], cache: caching, session: @session_name, took: Time.new - s[:start], key: s[:cache_key], status: status_code))
        end
      end
    end
  end
end
