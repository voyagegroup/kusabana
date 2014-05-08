# coding: UTF-8
require 'elasticsearch'
require 'logger'

module Kusabana
  class Logger < ::Logger
    def initialize(*args)
      super
      @es, @index = [nil, nil]
      if es = args[2][:es]
        # Convert keys to symbol from string
        hosts = es['hosts'].map do |v|
          v.inject({}) {|memo,(k,v)| memo[k.to_sym] = v; memo}
        end

        @es = Elasticsearch::Client.new(hosts: hosts)
        @index = es['index']
      end
      @formatter = LogFormatter.new(@es, @index)
    end

    def req(args={})
      args[:type] = 'req'
      info(args)
    end

    def res(args={})
      args[:type] = 'res'
      info(args)
    end
    
    class LogFormatter < ::Logger::Formatter
      def initialize(es, index)
        @es = es
        @index = index
      end

      def call(severity, timestamp, progname, msg)
        case msg
        when Array
          return msg.map{|v| call(severity, timestamp, progname, v) }.join('')
        when String
          msg = {message: msg}
        end
        msg[:@timestamp] = timestamp.to_datetime.to_s
        if @es
          type = msg.delete(:type)
          Thread.new do
            @es.index(index: @index, type: type, body: msg)
          end
        end
        raws = msg.inject([]) { |h, (key, value)| h << "#{key}:#{value}"; h }
        "#{raws.join("\t")}\n"
      end 
    end
  end
end
