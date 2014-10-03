class APN::Connection
  include APN::Base
  TIMES_TO_RETRY_SOCKET_ERROR = 2
  IDLE_RECONNECTION_INTERVAL = 120

  @production_senders = Hash.new
  @sandbox_senders = Hash.new
  @enterprise_senders = Hash.new

  @production_last_accesses = Hash.new
  @sandbox_last_accesses = Hash.new
  @enterprise_last_accesses = Hash.new

  def push_fifo(env, token)
    @fifos[env] <<= token
    @fifos[env].shift if @fifos[env][FIFO_SIZE]
  end

  def error_response
    if socket.flush && IO.select([socket], nil, nil, 1) && (error = socket.read(6))
      error = error.unpack("ccA*")
      log(:error, "Error response: #{error}")
    end

    error
  end

  def send_to_apple(notification, token, env, tag, debug = false)
    retries = 0
    push_fifo(env, token)

    begin
      socket.write(notification.to_s)
      return false if debug && error_response

      true
    rescue => e
      log(:error, "Try #{retries}: #{e.class} to #{apn_host}: #{e.message}, recent_tokens: #{@fifos[env]}")

      # Try reestablishing the connection
      if (retries += 1) <= TIMES_TO_RETRY_SOCKET_ERROR
        reconnect
        retry
      end

      log(:error, "#{e.class} to #{apn_host}: #{e.message}, recent_tokens: #{@fifos[env]}")
      raise e
    end
  end

  def reconnect
    teardown_connection
    sleep 1
    setup_connection
  end

  def self.current(sandbox = false, enterprise = false)
    thread_id = Thread.current.object_id
    epoch = Time.now.to_i

    # Use only 1 single thread for internal enterprise cert
    if enterprise
      if @enterprise_senders[thread_id] && (epoch - @enterprise_last_accesses[thread_id]) > IDLE_RECONNECTION_INTERVAL
        @enterprise_senders[thread_id].reconnect
      end

      @enterprise_last_accesses[thread_id] = epoch
      @enterprise_senders[thread_id] ||= new(worker_count: 1, verbose: 1, enterprise: 1)
    elsif sandbox
      if @sandbox_senders[thread_id] && (epoch - @sandbox_last_accesses[thread_id]) > IDLE_RECONNECTION_INTERVAL
        @sandbox_senders[thread_id].reconnect
      end

      @sandbox_last_accesses[thread_id] = epoch
      @sandbox_senders[thread_id] ||= new(worker_count: 1, sandbox: 1, verbose: 1)
    else
      if @production_senders[thread_id] && (epoch - @production_last_accesses[thread_id]) > IDLE_RECONNECTION_INTERVAL
        @production_senders[thread_id].reconnect
      end

      @production_last_accesses[thread_id] = epoch
      @production_senders[thread_id] ||= new(worker_count: 1, verbose: 1)
    end
  end

  def self.send_apn(token, message, sandbox = false, enterprise = false, style = { format: :frame })
    style.symbolize_keys!
    msg = APN::Notification.new(token, message, style.reverse_merge(identifier: token.byteslice(0, 4)))
    raise "Invalid notification message (did you provide :alert, :badge, :sound, or :'content-available'?): #{message.inspect}" unless msg.valid?

    sender = current(sandbox, enterprise)
    env = sandbox ? 'sandbox' : enterprise ? 'enterprise' : 'production'
    tag = "#{sandbox ? 'sandbox' : 'production'}#{enterprise ? ' enterprise' : ''}"
    sender.log(:info, "token: #{token} message: #{message}, style: #{style}")
    debug = style[:debug] || (style[:debug_sample] && rand(style[:debug_sample].to_i) == 0)
    sender.send_to_apple(msg, token, env, tag, debug)
    sender
  end

  self.singleton_class.send(:alias_method, :send, :send_apn)

  protected
  def apn_host
    @apn_host ||= apn_sandbox? ? "gateway.sandbox.push.apple.com" : "gateway.push.apple.com"
  end

  def apn_port
    2195
  end
end

