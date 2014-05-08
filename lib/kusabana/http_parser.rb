# coding: UTF-8
require 'http/parser'

module Http
  class Parser
    def cache_key(body)
      "#{http_method}::#{request_url}::#{body.hash}"
    end
  end
end
