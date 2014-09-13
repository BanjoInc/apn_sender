# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{banjo-apn_sender}
  s.version = "2.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Kali Donovan}, %q{KW Justin Leung}]
  s.date = %q{2012-06-19}
  s.description = %q{Based on Kali Donovan's APN sender 1.x. 2.0 keep things lean - we removed the resque layer, and make APN connection pluggable to multithreaded background worker (like SideKiq) to send Apple Push Notifications over a persistent TCP socket.}
  s.email = %q{kali.donovan@gmail.com justin@teambanjo.com}
  s.extra_rdoc_files = [ "LICENSE", "README.rdoc" ]
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.homepage = %q{http://github.com/BanjoInc/apn_sender}
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.6}
  s.summary = %q{APN connection pluggable to multithreaded background worker (like SideKiq) to send Apple Push Notifications over a persistent TCP socket.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<multi_json>, [">= 0"])
    else
      s.add_dependency(%q<multi_json>, [">= 0"])
    end
  else
    s.add_dependency(%q<multi_json>, [">= 0"])
  end
end

