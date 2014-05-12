kusabana
========
test proxy for Elasticsearch

### Require
memcached  
ruby => 2.1.1 (maybe work also in ruby => 2.0)

### Config
    proxy:
      host: '0.0.0.0'
      port: 9292
      daemonize: false
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
  - host, port: Host and port used by Kusabana
  - daemonize: When true, Kusabana will work as daemon
  - output: The file for output log. If you make it comment out, the log will output to STDOUT
  - pid: Used by daemon mode (default value is './kusabana.pid')
* es
  - remote: The ElasticSearch used for proxying access
  - output: The ElasticSearch used to store and to aggregate Kusabana's log
* cache
  - url: Memcached url

### Installation
    bundle install

#### Template
    bundle exec rake temprate:create

#### Dashboard
    bundle exec rake dashboard:create

Then, you can see kusabana's dashboard at `/dashboard/elasticsearch/kusabana`

### Launch
    make install
    bundle exec rake start

### Docker
You can also build Docker image
    
    rake docker:run
    # or
    rake docker:start

When it's first build, it takes big time because of buliding ruby environment.
Editing `FROM` statement in Dockerfile, it will be Saving time.

### Build Gem
    bundle exec rake build
