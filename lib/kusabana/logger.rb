# coding: UTF-8
require 'logger'
require 'oj'
require 'yaml'
require 'eventmachine'
require 'elasticsearch'
require 'thread'

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
      @stats = Queue.new
      @bulk = Queue.new
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
      when Hash
        super
      else
        add(args[0], args[1], message: args[2].to_s)
      end
    end

    def interval
      size = @bulk.size
      if size > 0
        bulk = size.times.map do |i|
          @bulk.pop
        end
        EM.defer -> do
          if bulk.length > 1
            @es.bulk(index: @index, body: bulk)
          elsif bulk.length == 1
            body = bulk[0][:index]
            @es.index(index: @index, type: body[:_type], body: body.reject{|k, v| k == :type })
          end
        end, ->(result) do
          stat
          EM.add_timer(300) { interval }
        end
      else
        stat
        EM.add_timer(300) { interval }
      end
    end

    def stat
      size = @stats.size
      if size > 0
        stats = size.times.map do |i|
          @stats.pop
        end
        body = stats.map do |s|
          if s[:to] < Time.new
            YAML.load <<-"EOS"
              size: 0
              query:
                filtered:
                  query:
                    match_all: {}
                  filter:
                    and:
                    - range:
                        '@timestamp':
                          gt: "#{s[:from].to_datetime}"
                          lt: "#{s[:to].to_datetime}"
                    - term:
                        key.no_analyzed: #{s[:key]}
                        cache: use
              aggs:
                count:
                  stats:
                    field: took
            EOS
          else
            @stats << s
            nil
          end
        end.compact
        if body.length > 0
          EM.defer(-> do
            if body.length > 1
              @es.msearch(index: @index, type: 'res', body: body)['responses']
            elsif body.length ==1
              [@es.search(index: @index, type: 'res', body: body[0])]
            end
          end, ->(results) do
            results.each_with_index do |result, i|
              agg = result['aggregations']['count']
              info(agg.merge(type: 'stat', key: stats[i][:key], from: stats[i][:from].to_datetime.to_s, to: stats[i][:to].to_datetime.to_s, efficiency: stats[i][:took] * agg['count'] / stats[i][:expire], expire: stats[i][:expire]))
            end
          end)
        end
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
          @logger.stats << {key: msg[:key], from: timestamp, to: timestamp+msg[:expire], took: msg[:took], expire: msg[:expire]}
        end
        raws = msg.inject([]) { |h, (key, value)| h << "#{key}:#{value}"; h }
        "#{raws.join("\t")}\n"
      end 
    end
  end
end
