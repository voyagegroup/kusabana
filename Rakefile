require 'yaml'

config = YAML.load_file("config.yml")

task :start do
  sh "bundle exec bin/kusabana"
end

task :stop do
  sh "kill `cat #{config['proxy']['pid']}`"
end

task :restart => [:stop, :start]
