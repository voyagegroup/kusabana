require 'bundler/gem_tasks'
require 'elasticsearch'
require 'yaml'
require 'oj'

config = YAML.load_file("config.yml")

def get_pid(config)
  begin
    open(config['proxy']['pid'] || 'kusabana.pid').read
  rescue Errno::ENOENT
    nil
  end
end

def alive?(pid)
  begin
    Process.kill(0, pid)
  rescue Errno::ESRCH
    nil
  end
end

desc 'Start Kusabana'
task :start do
  if config['proxy']['daemonize']
    pid = get_pid(config)
    if pid && alive?(pid.to_i)
      fail('Kusabana is already running')
    end
  end
  sh 'bundle exec bin/kusabana'
end

desc 'Stop Kusabana running as a daemon'
task :stop do
  pid = get_pid(config)
  if pid
    sh "kill #{pid}" if alive?(pid.to_i)
  end
end

desc 'Restart Kusabana running as a daemon'
task :restart => [:stop, :start]

desc 'Run RSpec'
task :test do
  sh 'bundle exec rspec'
end

# Tasks for Docker
namespace :docker do
  def get_container_id
    begin
      open('docker.id').read
    rescue Errno::ENOENT
      nil
    end
  end

  def container_alive?(id)
    alives = `docker ps -a -q`
    alives.each_line do |alive|
      return true if id.index(alive[0..-2]) == 0
    end
    return false
  end

  desc 'Build Docker image'
  task :build do
    sh 'docker build -t kusabana .'
  end

  desc 'Run Docker container'
  task :run => 'docker:build' do
    sh 'docker run -p 9292:9292 -t -i --rm kusabana'
  end

  desc 'Start Docker container'
  task :start => 'docker:build' do
    if last_id = get_container_id
      fail('Container is already running') if container_alive?(last_id)
    end
    sh 'docker run -p 9292:9292 -d kusabana > docker.id'
  end

  desc 'Stop Docker container running as a daemon'
  task :stop do
    if last_id = get_container_id
      sh "docker rm -f #{last_id}" if container_alive?(last_id)
    else
      fail('Container isn\'t running')
   end
  end

  desc 'Restart Docker container running as a daemon'
  task :restart => [:stop, :start]

  desc 'Run RSpec within Docker container'
  task :test => 'docker:build' do
    sh 'docker run -p 9292:9292 --rm kusabana test'
  end
end

namespace :dashboard do
  desc 'Create dashboard into output elasticsearch'
  task :create do
    hosts = config['es']['output']['hosts'].map do |v|
      v.inject({}) {|memo,(k,v)| memo[k.to_sym] = v; memo}
    end
    es = Elasticsearch::Client.new(hosts: hosts)
    body = Oj.load(open('kibana-dashboard.json'), mode: :compat)
    es.index(index: 'kibana-int', type: 'dashboard', id: 'kusabana', body: body)
  end
end
