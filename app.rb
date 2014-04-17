require 'rubygems'
require 'sinatra/base'
require 'sinatra/config_file'
 require "sinatra/reloader"
require 'oj'
require 'elasticsearch'

class Kusabana < Sinatra::Base
  register Sinatra::ConfigFile
  config_file 'config.yml'

  helpers do
    def client
      Elasticsearch::Client.new(url: settings.es[:url])
    end
  end

  configure :development do
    register Sinatra::Reloader
  end

  post '/_serch' do
  end

  get '/_nodes' do
    Oj.dump(client.nodes.stats, mode: :compat)
  end
end
