require 'bundler/gem_tasks'
require 'yaml'

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
      fail("Kusabana is already running")
    end
  end
  sh "bundle exec bin/kusabana"
end

desc 'Stop Kusabana running as a daemon'
task :stop do
  sh "kill #{get_pid(config)}"
end

desc 'Restart Kusabana running as a daemon'
task :restart => [:stop, :start]
