# coding: UTF-8
require 'logger'
require 'oj'
require 'yaml'
require 'eventmachine'
require 'elasticsearch'

module Kusabana
  class Logger < ::Logger
    attr_accessor :stats, :bulk
    def initialize(output, splits, env) 
      super(output, splits)
      @es, @index = [nil, nil]
      if env.config['es'].key?('output')
        # Convert keys to symbol from string
        hosts = env.config['es']['output']['hosts'].map do |v|
          v.inject({}) {|memo,(k,v)| memo[k.to_sym] = v; memo}
        end
        @es = Elasticsearch::Client.new(hosts: hosts)
        @index = env.config['es']['output']['index']
      end
      @formatter = LogFormatter.new(self, @es, @index)
      @stats = []
      @bulk = []
    end

    def req(args={})
      args[:type] = 'req'
      info(args)
    end

    def res(args={})
      args[:type] = 'res'
      info(args)
    end
    
    def add(*args)
      case args[2]
      when Array
        args[2].each{|v| add(args[0], args[1], v) }
      when String
        add(args[0], args[1], message: args[2])
      else
        EM.next_tick do
          super
        end
      end
    end

    def interval
      EM.defer -> do
        @es.bulk(body:@bulk, index: @index)
      end, ->(result) do
        @bulk.clear
        stat
      end
    end

    def stat
      if s = @stats.shift
        body_yaml = <<-"EOS"
          size: 0
          query:
            filtered:
              query:
                match_all: {}
              filter:
                and:
                - range:
                   '@timestamp':
                      gt: '#{s[:from]}'
                      lt: '#{s[:to]}'
                - term:
                    key.no_analyzed: #{s[:key]}
                    cache: use
          aggs:
            count:
              stats:
                field: took
        EOS
        body = YAML.load(body_yaml)
        EM.defer -> do
          @es.search(index: @index, body: body)
        end, ->(result) do
          agg = result['aggregations']['count']
          info(agg.merge(type: 'stat', key: s[:key], from: s[:from], to: s[:to], efficiency: s[:took] * agg['count'] / s[:expire], expire: s[:expire]))
        end
        stat
      end
    end
    
    class LogFormatter < ::Logger::Formatter
      def initialize(logger, es, index)
        @logger = logger
        @es = es
        @index = index
      end

      def call(severity, timestamp, progname, msg)
        msg[:@timestamp] = timestamp.to_datetime.to_s
        if @es && msg.key?(:type)
          @logger.bulk << {index: {_type: msg[:type], data: msg.reject{|k, v| k == :type }}}
        end
        if msg[:cache] == 'store'
           @logger.stats << {key: msg[:key], from: msg[:@timestamp], to: (timestamp+msg[:expire]).to_datetime.to_s, took: msg[:took], expire: msg[:expire]}
        end
        raws = msg.inject([]) { |h, (key, value)| h << "#{key}:#{value}"; h }
        "#{raws.join("\t")}\n"
      end 
    end
  end
end
