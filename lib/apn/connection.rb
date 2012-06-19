class APN::Connection
  include APN::Base
  TIMES_TO_RETRY_SOCKET_ERROR = 2

  @production_senders = Hash.new
  @sandbox_senders = Hash.new

  def send_to_apple(notification)
    retries = 0

    begin
      self.socket.write( notification.to_s )
    rescue => e
      Rails.logger.error("Try #{retries}: APNConnection to #{apn_host} error with #{e}")

      # Try reestablishing the connection
      if (retries += 1) <= TIMES_TO_RETRY_SOCKET_ERROR
        teardown_connection
        setup_connection
        retry
      end

      Rails.logger.error("APNConnection gave up send_to_apple after #{retries} failures")
      raise e
    end
  end

  def self.send(token, options, sandbox = false)
    msg = APN::Notification.new(token, options)
    raise "Invalid notification options (did you provide :alert, :badge, or :sound?): #{options.inspect}" unless msg.valid?

    thread_id = Thread.current.object_id

    sender = if sandbox
      @sandbox_senders[thread_id] ||= new(worker_count: 1, sandbox: 1, verbose: 1)
    else
      @production_senders[thread_id] ||= new(worker_count: 1, verbose: 1)
    end
     
    Rails.logger.info "[APNConnection:#{sender.object_id} #{sandbox ? 'sandbox' : 'production'}] token: #{token} message: #{options}"
    sender.send_to_apple(msg)
  end

  protected
  def apn_host
    @apn_host ||= apn_sandbox? ? "gateway.sandbox.push.apple.com" : "gateway.push.apple.com"
  end

  def apn_port
    2195
  end
end

