# coding: UTF-8
require 'oj'

module Kusabana
  class Rule
    attr_reader :expired
    def initialize(method, pattern, expired, &modifier)
      @method = method
      @pattern = pattern
      @expired = expired
      @modifier = modifier
    end

    def match(method, path)
      b = @method == method && @pattern =~ path
      @path = path if b
      b
    end

    def modify(query)
      modified = @modifier.call(Oj.load(query, mode: :compat))
      [Oj.dump(modified, mode: :compat), "#{@method}::#{@path}::#{modified.hash}"]
    end
  end
end
