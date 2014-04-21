# coding: UTF-8
require 'oj'

module Kusabana
  class Rule
    attr_reader :expired
    def initialize(method, pattern, expired)
      @method = method
      @pattern = pattern
      @expired = expired
      if block_given?
        @modifier = -> (query) { yield query }
      else
        @modifier = -> (query) { query }
      end
    end

    def match(method, path)
      b = @method == method && @pattern =~ path
      @path = path if b
      b
    end

    def modify(query)
      if query
        modified = @modifier.call(Oj.load(query, mode: :compat))
        [Oj.dump(modified, mode: :compat), "#{@method}::#{@path}::#{modified.hash}"]
      else
        [nil, "#{@method}::#{@path}"]
      end
    end
  end
end
