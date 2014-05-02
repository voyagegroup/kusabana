kusabana
========
test proxy for Elasticsearch

### Require
memcached  
ruby => 2.1.1 (maybe work also in ruby => 2.0)

### Config
See and Edit and Rename `config.yml.sample`.

### Launch
#### Classic
    make install
    bundle exec rake start

#### Docker
You can also build Docker image
    
    docker build -t <your_name>/kusabana .
    docker run --rm -i -t -p 9292:9292 <your_name>/kusabana

When it's first build, it takes big time because of buliding ruby environment.
Editing `FROM` statement in Dockerfile, it will be Saving time.

### Build Gem
    bundle exec rake build
