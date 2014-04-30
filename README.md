kusabana
========

test proxy for Elasticsearch

### require
memcached

### launch
Edit `config.yml`. Then,

    bundle install
    bundle exec bin/kusabana

or

    gem build kusabana.gemspec
    gem install kusabana-*.gem
    kusabana
