# coding: UTF-8
require 'memcached'

module Kusabana
  class Cache < Memcached
    def get(key)
      begin
        super(key)
      rescue Memcached::ServerIsMarkedDead
        nil
      end
    end

    def get_or_nil(key)
      begin
        get(key)
      rescue Memcached::NotFound
        nil
      end
    end

    def set(key, value, ttl=@default_ttl, encode=true, flags=FLAGS)
      begin
        super(key, value, ttl, encode, flags)
        true
      rescue Memcached::ServerIsMarkedDead
        false
      end
    end
  end
end
