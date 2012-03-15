# Slight modifications from the default Resque tasks
namespace :apn do
  task setup: :environment
  task work: :sender
  task workers: :senders

  desc "Start an APN worker"
  task sender: :setup do
    require 'apn'

    worker = nil

    begin
      worker = APN::Sender.new(full_cert_path: ENV['FULL_CERT_PATH'], cert_path: ENV['CERT_PATH'], environment: ENV['ENVIRONMENT'], sandbox: ENV['SANDBOX'].present?)
      worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
      worker.very_verbose = ENV['VVERBOSE']
    rescue Exception => e
      raise e
      # abort "set QUEUE env var, e.g. $ QUEUE=critical,high rake resque:work"
    end

    puts "*** Starting worker to send apple notifications in the background from #{worker}"

    worker.work(ENV['INTERVAL'] || 0.5) # interval, will block
  end

  desc "Start multiple APN workers. Should only be used in dev mode."
  task :senders do
    threads = []

    ENV['COUNT'].to_i.times do
      threads << Thread.new do
        system "rake apn:work"
      end
    end

    threads.each { |thread| thread.join }
  end
end
