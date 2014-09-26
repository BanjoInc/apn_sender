require 'socket'
require 'openssl'

module APN
    # APN::Base takes care of all the boring certificate loading, socket creating, and logging
    # responsibilities so APN::Sender and APN::Feedback and focus on their respective specialties.
    module Base
      attr_accessor :opts, :logger, :fifos
      
      FIFO_SIZE = 5
      
      def initialize(opts = {})
        @opts = opts
        @fifos = Hash.new { [] }

        setup_logger
        setup_paths
        log(:info, "APN::Sender with opts #{@opts}")
      end
      
      # Lazy-connect the socket once we try to access it in some way
      def socket
        setup_connection unless @socket
        return @socket
      end
            
      # Log message to any logger provided by the user (e.g. the Rails logger).
      # Accepts +log_level+, +message+, since that seems to make the most sense,
      # and just +message+, to be compatible with Resque's log method and to enable
      # sending verbose and very_verbose worker messages to e.g. the rails logger.
      #
      # Perhaps a method definition of +message, +level+ would make more sense, but
      # that's also the complete opposite of what anyone comming from rails would expect.
      def log(level, message = nil)
        level, message = 'info', level if message.nil? # Handle only one argument if called from Resque, which expects only message

        return false unless self.logger && self.logger.respond_to?(level)
        self.logger.send(level, "[APNConnection:#{object_id} #{apn_environment}] #{message}")
      end
      
      # Log the message first, to ensure it reports what went wrong if in daemon mode. 
      # Then die, because something went horribly wrong.
      def log_and_die(msg)
        log(:fatal, msg)
        raise msg
      end
      
      protected
      # Default to Rails logger, if available
      def setup_logger
        @logger = defined?(::Rails.logger) ? ::Rails.logger : Logger.new(STDOUT)
      end
      
      def apn_enterprise?
        @apn_enterprise ||= @opts[:enterprise].present?
      end      

      def apn_sandbox?
        @apn_sandbox ||= @opts[:sandbox].present?
      end
      
      def apn_enterprise?
        @apn_enterprise ||= @opts[:enterprise].present?
      end
      
      def apn_environment
        @apn_envoironment ||= (apn_sandbox? ? 'sandbox' : 'production') + (apn_enterprise? ? '_enterprise' : '')
      end
      
      # Get a fix on the .pem certificate we'll be using for SSL
      def setup_paths
        @opts[:environment] ||= ::Rails.env if defined?(::Rails.env)

        # Accept a complete :full_cert_path allowing arbitrary certificate names, or create a default from the Rails env
        cert_path = @opts[:full_cert_path] || begin
          # Note that RAILS_ROOT is still here not from Rails, but to handle passing in root from sender_daemon
          @opts[:root_path] ||= defined?(::Rails.root) ? ::Rails.root.to_s : (defined?(RAILS_ROOT) ? RAILS_ROOT : '/')
          @opts[:cert_path] ||= File.join(File.expand_path(@opts[:root_path]), "config", "certs")
          @opts[:cert_name] ||= 'apn_' + ::Rails.env + (apn_sandbox? ? '_sandbox' : '') + (apn_enterprise? ? '_enterprise' : '') + '.pem'

          File.join(@opts[:cert_path], @opts[:cert_name])
        end
        
        log(:info, "APN environment=#{apn_environment}, Rails environment=#{::Rails.env}, using cert #{cert_path}")
        @apn_cert = File.read(cert_path) if File.exists?(cert_path)
        log_and_die("Please specify correct :full_cert_path. No apple push notification certificate found in: #{cert_path}") unless @apn_cert
      end
      
      # Open socket to Apple's servers
      def setup_connection
        log_and_die("Missing apple push notification certificate") unless @apn_cert
        return true if @socket && @socket_tcp && !@socket.closed? && !@socket_tcp.closed?
        log_and_die("Trying to open half-open connection") if (@socket && !@socket.closed?) || (@socket_tcp && !@socket_tcp.closed?)

        log(:info, "Setting up SSL connection to APN...")
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.cert = OpenSSL::X509::Certificate.new(@apn_cert)
        ctx.key = OpenSSL::PKey::RSA.new(@apn_cert)

        @socket_tcp = TCPSocket.new(apn_host, apn_port)
        @socket_tcp.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)

        @socket = OpenSSL::SSL::SSLSocket.new(@socket_tcp, ctx)
        @socket.sync = true
        @socket.connect
      rescue SocketError => error
        log_and_die("Error with connection to #{apn_host}: #{error}")
      end

      # Close open sockets
      def teardown_connection
        log(:info, "Closing connections...") if @opts[:verbose]

        begin
          @socket.close if @socket
        rescue Exception => e
          log(:error, "Error closing SSL Socket: #{e}")
        end

        begin
          @socket_tcp.close if @socket_tcp && !@socket_tcp.closed?
        rescue Exception => e
          log(:error, "Error closing TCP Socket: #{e}")
        end
      end
    end
end
