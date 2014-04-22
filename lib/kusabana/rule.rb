# coding: UTF-8
require 'oj'

module Kusabana
  class Rule
    attr_reader :expired
    def initialize(method, pattern, expired)
      @method = method
      @pattern = pattern
      @expired = expired
      @modifiers = []
    end

    def add_modifier(modifier)
      @modifiers << modifier
    end

    def match(method, path)
      b = @method == method && @pattern =~ path
      @path = path if b
      b
    end

    def modify(query)
      if query
        modified = scan_query(Oj.load(query, mode: :compat))
        [Oj.dump(modified, mode: :compat), "#{@method}::#{@path}::#{modified.hash}"]
      else
        [nil, "#{@method}::#{@path}"]
      end
    end

    private
    def scan_query(query)
      case query
      when ::Hash
        query.inject({}) do |hash, (key, value)|
          value = -> do
            @modifiers.each do |mod|
              return mod.modify(value) if mod.pattern =~ key
            end
            scan_query(value)
          end.call
          hash[key] = value
          hash
        end
      when ::Array
        query.map do |value|
          scan_query(value)
        end
      else
        query
      end
    end
  end

  class QueryModifier
    attr_reader :pattern
    def initialize(pattern, &block)
      @pattern = pattern
      @block = block
    end

    def modify(query)
      @block.call(query)
    end
  end
end
