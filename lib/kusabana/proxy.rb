require 'memcached'
require 'em-proxy'
require 'uuid'
require 'http/parser'
require 'logger'

module Kusabana
  class Proxy < ::Logger::Application
		def initialize(rules, config)
			@rules = rules
			@config = config
			super('Kusabana')
		end

    def run
			config = @config
			rules = @rules
			log = @log
      ::Proxy.start(:host => config['proxy']['host'], :port => config['proxy']['port']) do |conn|
				@cache = Memcached.new(config['cache']['url'])
				@sessions = {}

				# Request
				@req_buffer = ''

				@req_parser = HTTP::Parser.new
				@req_parser.on_body = -> (body) do
					@body = body
				end

				@req_parser.on_message_complete = -> do 
					session = UUID.generate :compact
					s = conn.server session, :host => config['es']['host'], :port => config['es']['port']
					log.info("t=req,m=#{@req_parser.http_method},p=#{@req_parser.request_url},r=#{@req_parser.headers['Host']},s=#{session}")
					req = -> do
						rules.each do |rule|
							if rule.match(@req_parser.http_method,@req_parser.request_url)
								modified, hash = rule.modify(@body)
								if res = @cache.get_or_nil(hash)
									conn.send_data res
									log.info("t=res,m=#{@req_parser.http_method},c=use,p=#{@req_parser.request_url},s=#{session}")
									return nil
								else
									@sessions[session] = {rule: rule, hash: hash}
									return @req_buffer.gsub(/\r\n\r\n.+/m, "\r\n\r\n#{modified}")
								end
							end
						end
						@req_buffer
					end
					
					if req = req.call
						s.send_data req
					end
					@req_buffer.clear
				end

				conn.on_data do |data|
					@req_buffer << data
					@req_parser << data
					:async
				end


				# Response
				@res_buffer = ''

				@res_parser = HTTP::Parser.new
				@res_parser.on_message_complete = -> do
					caching = 'no'
					if s = @sessions[@session]
						@cache.set(s[:hash], @res_buffer, s[:rule].expired)
						caching = 'store'
					end
					log.info("t=res,m=#{@req_parser.http_method},p=#{@req_parser.request_url},c=#{caching},s=#{@session}")
					@sessions.delete_if {|k, v| v == @session }
					@res_buffer.clear
				end

				conn.on_response do |backend, resp|
					@session = backend
					@res_buffer << resp
					@res_parser << resp
					resp
				end
			end
		end
	end
end
