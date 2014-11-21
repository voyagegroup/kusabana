FROM ruby

RUN apt-get update
RUN apt-get upgrade -y

# Install kusabana
RUN mkdir /kusabana
WORKDIR /kusabana

# Add Gemfile and run bundle install
RUN apt-get install -y libsasl2-dev git build-essential ruby2.1-dev
RUN gem install bundle
ADD ./Gemfile /kusabana/Gemfile
ADD ./kusabana.gemspec /kusabana/kusabana.gemspec
ADD ./lib/kusabana/version.rb /kusabana/lib/kusabana/version.rb
RUN bundle install -j 4

# Add any other file
RUN mv Gemfile.lock Gemfile.lock.tmp
ADD . /kusabana/
RUN rm -rf .bundle
RUN mv Gemfile.lock.tmp Gemfile.lock

EXPOSE 9292
ENTRYPOINT ["bundle", "exec"]
