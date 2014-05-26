FROM ubuntu:trusty

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y software-properties-common

# Install ruby-2.1
RUN add-apt-repository -y ppa:brightbox/ruby-ng
RUN apt-get update
RUN apt-get install -y ruby2.1

# Install kusabana
RUN mkdir /kusabana
WORKDIR /kusabana

# Add Gemfile and run bundle install
RUN apt-get install -y libsasl2-dev git build-essential ruby2.1-dev
RUN gem install bundle
ADD ./Gemfile /kusabana/Gemfile
ADD ./kusabana.gemspec /kusabana/kusabana.gemspec
ADD ./lib/kusabana/version.rb /kusabana/lib/kusabana/version.rb
RUN bundle install

# Add any other file
RUN mv Gemfile.lock Gemfile.lock.tmp
ADD . /kusabana/
RUN mv Gemfile.lock.tmp Gemfile.lock

ADD ./karakuri.yml /karakuri.yml

EXPOSE 9292
ENTRYPOINT ["bundle", "exec", "rake"]
CMD ["start"]
