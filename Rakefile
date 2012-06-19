require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "apn_sender"
    gem.summary = %Q{APN connection pluggable to multithreaded background worker (like SideKiq) to send Apple Push Notifications over a persistent TCP socket.}
    gem.description = %Q{Based on Kali Donovan's APN sender 1.x. 2.0 keep things lean - we removed the resque layer, and make APN connection pluggable to multithreaded background worker (like SideKiq) to send Apple Push Notifications over a persistent TCP socket.}
    gem.email = "kali.donovan@gmail.com justin@teambanjo.com"
    gem.homepage = "http://github.com/BanjoInc/apn_sender"
    gem.authors = ["Kali Donovan", "KW Justin Leung"]
    gem.add_dependency 'yajl-ruby'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
