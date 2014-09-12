module APN
  # Encapsulates the logic necessary to convert an iPhone token and an array of options into a string of the format required
  # by Apple's servers to send the notification.  Much of the processing code here copied with many thanks from
  # http://github.com/samsoffes/apple_push_notification/blob/master/lib/apple_push_notification.rb
  #
  # APN::Notification.new's first argument is the token of the iPhone which should receive the notification.  The second argument
  # is a hash with any of :alert, :badge, and :sound keys. All three accept string arguments, while :sound can also be set to +true+
  # to play the default sound installed with the application. At least one of these keys must exist.  Any other keys are merged into
  # the root of the hash payload ultimately sent to the iPhone:
  #
  #   APN::Notification.new(token, {:alert => 'Stuff', :custom => {:code => 23}})
  #   # Writes this JSON to servers: {"aps" => {"alert" => "Stuff"}, "custom" => {"code" => 23}}
  # 
  # As a shortcut, APN::Notification.new also accepts a string as the second argument, which it converts into the alert to send.  The 
  # following two lines are equivalent:
  #
  #   APN::Notification.new(token, 'Some Alert')
  #   APN::Notification.new(token, {:alert => 'Some Alert'})
  #
  class Notification
    # Available to help clients determine before they create the notification if their message will be too large.
    # Each iPhone Notification payload must be 256 or fewer characters.  Encoding a null message has a 57 
    # character overhead, so there are 199 characters available for the alert string.
    MAX_ALERT_LENGTH = 199

    attr_accessor :options, :token, :format, :identifier, :expiry_epoch, :priority

    def initialize(token, opts, style = {})
      @token = token
      @options = hash_as_symbols(opts.is_a?(Hash) ? opts : {:alert => opts})
      @format = style[:format] || :frame
      @identifier = style[:identifier] || OpenSSL::Random.random_bytes(4)
      @expiry_epoch = (style[:expiry_epoch] || Time.now + 1.hour).to_i
      @priority = (style[:priority] || 10).to_i
      payload_size = packaged_message.bytesize.to_i

      raise "Payload bytesize of #{payload_size} is > the maximum allowed size of 255." if payload_size > 255
    end

    def to_s
      packaged_notification
    end

    # Ensures at least one of <code>%w(alert badge sound)</code> is present
    def valid?
      return true if %w(alert badge sound content-available).any?{|key| options.keys.include?(key.to_sym) }
      false
    end

    # Converts the supplied options into the JSON needed for Apple's push notification servers.
    # Extracts :alert, :badge, :sound, 'aps' hash, merges 'custom' hash data
    # into the root of the hash to encode and send to apple.
    def packaged_message
      self.class.packaged_message(@options)
    end

    def self.packaged_message(options)
      raise "Message #{options} is missing the alert, badge, content-available keys." unless options[:badge] || options[:alert] || options[:'content-available']

      opts = options.clone # Don't destroy our pristine copy
      aps_hash = {}

      if sound = opts.delete(:sound)
        aps_hash['sound'] = sound.is_a?(TrueClass) ? 'default' : sound.to_s
      end

      hsh = { 'aps' => aps_hash }
      hsh.merge!(opts.delete(:custom) || {})
      hsh['aps'].merge!(opts)

      MultiJson.dump(hsh)
    end

    protected
    # Completed encoded notification, ready to send down the wire to Apple
    def packaged_notification
      pt = packaged_token
      pm = packaged_message

      case format
      when :simple
        [0, 0, pt.bytesize, pt, 0, pm.bytesize, pm].pack("ccca*cca*") 
      when :frame
        data = ''
        data << [1, pt.bytesize, pt].pack("CnA*")
        data << [2, pm.bytesize, pm].pack("CnA*")
        data << [3, identifier.bytesize, identifier].pack("CnA*")
        data << [4, 4, expiry_epoch].pack("CnN")
        data << [5, 1, priority].pack("CnC")

        [2, data.bytesize].pack('CN') + data
      else
        raise "Unsupported apn format #{format} with token: #{pt} message: #{options}"
      end
    end

    # Device token, compressed and hex-ified
    def packaged_token
      [@token.gsub(/[\s|<|>]/,'')].pack('H*')
    end

    # Symbolize keys, using ActiveSupport if available
    def hash_as_symbols(hash)
      if hash.respond_to?(:symbolize_keys)
        return hash.symbolize_keys
      else
        hash.inject({}) do |opt, (key, value)|
          opt[(key.to_sym rescue key) || key] = value
          opt
        end
      end
    end
  end
end

