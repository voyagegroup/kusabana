# coding: UTF-8
require 'elasticsearch'
require 'logger'

module Kusabana
  class Logger < ::Logger
    def initialize(*args)
      super
      @formatter = LogFormatter.new(args[1][:es])
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
      def initialize(es)
        super()
        @es = nil

        if es
          # Convert keys to symbol from string
          hosts = es['hosts'].map do |v|
            v.inject({}) {|memo,(k,v)| memo[k.to_sym] = v; memo}
          end

          @es = Elasticsearch::Client.new(hosts: hosts)
          @index = es['index']
        end
      end

      def call(severity, timestamp, progname, msg)
          msg[:@timestamp] = timestamp.to_datetime.to_s
        raws = []
        case msg
        when Hash
          raws = msg.inject(raws) { |h, (key, value)| h << "#{key}:#{value}"; h }
        when String
          raws << "message:#{msg}"
        end

        if @es
          type = msg.delete(:type)
          Thread.new do
            @es.index(index: @index, type: type, body: msg)
          end
        end
        "#{raws.join("\t")}\n"
      end 
    end
  end
end
