require 'rubygems'
require 'sinatra/base'
require 'sinatra/config_file'
require 'sinatra/reloader'
require 'oj'
require 'elasticsearch'
require 'memcached'
require 'net/http'
require 'rack/cors'
require 'uri'

class Kusabana < Sinatra::Base
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', :headers => :any, :methods => [:get, :post, :options]
    end
  end
  register Sinatra::ConfigFile
  config_file 'config.yml'

  helpers do
    def client
      Elasticsearch::Client.new(url: settings.es[:url])
    end

    def cache
      Memcached.new(settings.cache[:url])
    end
  end

  configure :development do
    register Sinatra::Reloader
  end

  before do
    content_type :json
  end

  before '/:index/_search' do
    request.body.rewind
    @query = Oj.load request.body.read, mode: :compat
  end

  post '/:index/_search' do |index|
    begin
      @query['facets']['terms']['facet_filter']['fquery']['query']['filtered']['filter']['bool']['must'].each do |filter|
        if range = filter.fetch('range', nil)
          if timestamp = range.fetch('@timestamp', nil)
            timestamp['from'] = timestamp['from'] / 100 * 100
            timestamp['to'] = timestamp['to'] / 100 * 100
          end
        end
      end
    rescue NoMethodError
    end
    key = "search.#{index[1..-1]}.#{@query.hash}"
    begin
      cache.get(key)
    rescue Memcached::NotFound
      results = Oj.dump(client.search(index: index, q: @query), mode: :compat)
      cache.set(key, results, 100)
      results
    end
  end

  get '/_nodes' do
    begin
      cache.get('nodes')
    rescue Memcached::NotFound
      nodes = Oj.dump(client.nodes.info, mode: :compat)
      cache.set('nodes', nodes, 60)
      nodes
    end
  end

  not_found do
    url = "http://#{settings.es[:url] + request.path_info}"
    Net::HTTP.send(request.request_method.downcase, URI.parse(url))
  end
end
