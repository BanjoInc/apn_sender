class APN::Connection
  include APN::Base
  TIMES_TO_RETRY_SOCKET_ERROR = 2

  @production_senders = Hash.new
  @sandbox_senders = Hash.new
  @enterprise_semaphore = Mutex.new


  def push_fifo(env, token)
    @fifos[env] <<= token
    @fifos[env].shift if @fifos[env][FIFO_SIZE]
  end

  def send_to_apple(notification, token, env, tag)
    retries = 0
    push_fifo(env, token)

    begin
      self.socket.write( notification.to_s )
    rescue => e
      log(:error, "Try #{retries}: #{e.class} to #{apn_host}: #{e.message}, recent_tokens: #{@fifos[env]}")

      # Try reestablishing the connection
      if (retries += 1) <= TIMES_TO_RETRY_SOCKET_ERROR
        teardown_connection
        sleep 1
        setup_connection
        retry
      end

      log(:error, "#{e.class} to #{apn_host}: #{e.message}, recent_tokens: #{@fifos[env]}")
      raise e
    end
  end

  def self.send(token, options, sandbox = false, enterprise = false)
    msg = APN::Notification.new(token, options)
    raise "Invalid notification options (did you provide :alert, :badge, or :sound?): #{options.inspect}" unless msg.valid?

    thread_id = Thread.current.object_id

    # Use only 1 single thread for internal enterprise cert
    sender = if enterprise
      if sandbox
        @sandbox_enterprise_sender ||= new(worker_count: 1, sandbox: 1, verbose: 1, enterprise: 1)
      else
        @production_enterprise_sender ||= new(worker_count: 1, verbose: 1, enterprise: 1)
      end 
    else
      if sandbox
        @sandbox_senders[thread_id] ||= new(worker_count: 1, sandbox: 1, verbose: 1)
      else
        @production_senders[thread_id] ||= new(worker_count: 1, verbose: 1)
      end
    end
     
    env = sandbox ? 'sandbox' : enterprise ? 'enterprise' : 'production'
    tag = "#{sandbox ? 'sandbox' : 'production'}#{enterprise ? ' enterprise' : ''}"
    sender.log(:info, "token: #{token} message: #{options}")

    if enterprise
      @enterprise_semaphore.synchronize { sender.send_to_apple(msg, token, env, tag) }
    else
      sender.send_to_apple(msg, token, env, tag)
    end
  end

  protected
  def apn_host
    @apn_host ||= apn_sandbox? ? "gateway.sandbox.push.apple.com" : "gateway.push.apple.com"
  end

  def apn_port
    2195
  end
end

