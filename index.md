---
layout: default
---
# Kasabana

About
-----
**Kusabana** is a proxy server between [Kibana](http://www.elasticsearch.org/overview/kibana/) and [ElasticSearch](http://www.elasticsearch.org/overview/elasticsearch).  
It also works as 'query cache' server.  

Design
------
**Kusabana** is coded by Ruby 2.0, depend on memcached.

Why
---
ElasticSearch + Kibana are becoming typical solution for data mining.  
However, it is said that they have some performance probrems.  
The query produced by kibana is variable by time, path or dashboard's environment.  
Futhermore, ElasticSearch doesn't have a mechanism of 'query cache' but for 'filter cache'.

Although caching, **Kusabana** can store log of itself to ElasticSearch.  
This will make you able to make configration easier.

Installation
------------
    git clone https://github.com/voyagegroup/kusabana
    cd kusabana
    bundle install

Because of `memcached` gem, it require `libsasl2-dev` or any other similer package.

Config
------
    proxy:
      host: '0.0.0.0'
      port: 9292
      daemonize: false
      timeout: 15
    # output: 'log/kusabana.log' 
    # pid: 'log/kusabana.pid'
    es:
      remote:
        host: 'localhost'
        port: 9200
    # output:
    #   index: 'kusabana-log-1'
    #   hosts:
    #   - host: 'localhost'
    #     port: 9200
    cache:
      url: 'localhost:11211'

* proxy
  - host, port: Host and port used by **Kusabana**
  - daemonize: When true, **Kusabana** will work as daemon
  - timeout: The seconds for harakiri each connection
  - output: The file for output log. If you make it comment out, the log will output to `STDOUT`
  - pid: Used by daemon mode (default value is `./kusabana.pid`)
* es
  - remote: The ElasticSearch used for proxying access
  - output: The ElasticSearch used to store and to aggregate **Kusabana**'s log
* cache
  - url: Memcached url

If you want to store **Kusabana**'s log and set output ElasticSearch, You should PUT index template to ES.  
Run

    bundle rake template:create

Additionally, You can use Kibana Dashboard for montoring **Kusabana**'s log.

    bundle rake dashboard:create

Then, the Dashboard is going to be seen at `/dashboard/elasticsearch/kusabana`.

Usage
-----
The configration of cache is available in `./bin/kusabana`.

    # Default settings
    rules = []
    search_caching = Kusabana::Rule.new('POST', /^\/.+\/_search(\?.+)?$/, 300)
    timestamp_modifier = Kusabana::QueryModifier.new(/@timestamp/) do |query|
      if query.key?('from') && query.key?('to')
        query['from'] = query['from'] / 100000 * 100000
        query['to'] = query['to'] / 100000 * 100000
      end
      query
    end
    search_caching.add_modifier(timestamp_modifier)
    rules << search_caching

    rules << Kusabana::Rule.new('GET', /^\/_nodes$/, 300)
    rules << Kusabana::Rule.new('GET', /^\/\S+\/_mapping$/, 300)
    rules << Kusabana::Rule.new('GET', /^\/\S+\/_aliases(\?.+)?$/, 300)

### Kusabana::Rule
    Kusabana::Rule.new(method, path_pattern, expire)

### Kusabana::QueryModifier
    Kusabana::QueryModifier.new(key_pattern, &block)

When **Kusabana** serve request, it will be checked whether there are any `Rule` that is matched by `method` and `path_pattern`.  
If match, **Kusabana** will try parsing query, scanning JSON's key and executing `$block` of matched `QueryModifier` by `key_pattern`.  
The query will be modified by returning of `&block`.

This behavior is made for ignoring tiny differents between queries(e.g. The filter by range of `@timestamp`).

Each `Rule` and `QueryModifier` is apply only first matched one.

Benchmark
---------

Contribute
----------
