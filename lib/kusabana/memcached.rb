# coding: UTF-8
class Memcached
  def get_or_nil(key)
    begin
      get(key)
    rescue Memcached::NotFound, Memcached::ServerIsMarkedDead
      nil
    end
  end
end
