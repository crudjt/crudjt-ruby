require 'ffi'
require 'json'
require 'msgpack'
require "grpc"

require_relative 'lru_cache'
require_relative 'validation'
require_relative 'errors'
require_relative 'generated/token_service_services_pb'
require_relative 'token_service_impl'

include CRUDJT::Validation

def load_store_jt_library
  os = case RbConfig::CONFIG['host_os']
       when /darwin|mac os/
         'macos'
       when /linux/
         'linux'
       when /mswin|mingw|cygwin/
         'windows'
       else
         raise "Unsupported OS: #{RbConfig::CONFIG['host_os']}"
       end

   arch = case RbConfig::CONFIG['host_cpu']
        when /x86_64|x64/
          'x86_64'
        when /arm|arm64/
          'arm64'
        else
          raise "Unsupported architecture: #{RbConfig::CONFIG['host_cpu']}"
        end

  lib_path = File.expand_path("../native/#{os}/store_jt_#{arch}", __FILE__)
  lib_path += '.dylib' if os == 'macos'
  lib_path += '.so' if os == 'linux'
  lib_path += '.dll' if os == 'windows'

  ffi_lib lib_path
end

module CRUDJT
  extend FFI::Library

  load_store_jt_library

  module Config
    extend FFI::Library

    load_store_jt_library

    GRPC_HOST = '127.0.0.1'
    GRPC_PORT = 50051

    attach_function :start_store_jt, [:string, :string], :string

    @settings = {}

    class << self
      def check_encrypted_key
        @settings[:encrypted_key]
      end

      def encrypted_key(value)
        CRUDJT::Validation.validate_encrypted_key!(value)

        @settings[:encrypted_key] = value
        self
      end

      def master?
        @settings[:master]
      end

      def was_started
        @was_started
      end

      def stub
        @stub
      end

      def start_master(options = {})
        raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_ALREADY_STARTED) if was_started
        raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_ENCRYPTED_KEY_NOT_SET) unless options[:encrypted_key]

        CRUDJT::Validation.validate_encrypted_key!(options[:encrypted_key])

        @settings[:encrypted_key] = options[:encrypted_key]
        @settings[:store_jt_path] = options[:store_jt_path]
        @settings[:grpc_host] = options[:grpc_host] || GRPC_HOST
        @settings[:grpc_port] = options[:grpc_port] || GRPC_PORT

        result = JSON(start_store_jt(@settings[:encrypted_key], @settings[:store_jt_path]))
        raise CRUDJT::ERRORS[result['code']], result['error_message'] unless result['ok']

        port = "#{@settings[:grpc_host]}:#{@settings[:grpc_port]}"
        grpc_server = TokenServiceImpl.call(port)

        at_exit do
          grpc_server.stop
        end

        Thread.new do
          grpc_server.run_till_terminated
        end

        @settings[:master] = true
        @was_started = true
      end

      def connect_to_master(options = {})
        raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_ALREADY_STARTED) if was_started

        @settings[:grpc_host] = options[:grpc_host] || GRPC_HOST
        @settings[:grpc_port] = options[:grpc_port] || GRPC_PORT
        port = "#{@settings[:grpc_host]}:#{@settings[:grpc_port]}"

        @_channel = GRPC::Core::Channel.new(
          port,
          nil,
          :this_channel_is_insecure
        )

        @stub = Token::TokenService::Stub.new(
          port,
          :this_channel_is_insecure
        )

        @settings[:master] = false
        @was_started = true
      end
    end
  end

  attach_function :__create, [:pointer, :size_t, :int, :int], :string
  attach_function :__read, [:string], :string
  attach_function :__update, [:string, :pointer, :size_t, :int, :int], :bool
  attach_function :__delete, [:string], :bool

  @lru_cache = CRUDJT::LRUCache.new(lambda { |token| __read(token) })

  def self.original_create(hash, ttl: nil, silence_read: nil)
    raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_NOT_STARTED) unless CRUDJT::Config.was_started
    CRUDJT::Validation.validate_insertion!(hash, ttl, silence_read)

    ttl ||= -1
    silence_read ||= -1

    packed_data = MessagePack.pack(hash)
    hash_bytesize = packed_data.bytesize
    CRUDJT::Validation.validate_hash_bytesize!(hash_bytesize)

    # Creation buffer with packed data
    buffer = FFI::MemoryPointer.new(:char, hash_bytesize)
    buffer.put_bytes(0, packed_data)

    token = __create(buffer, hash_bytesize, ttl, silence_read)
    raise CRUDJT::CRUDJT::ERRORS::InternalError, 'Something went wrong. Ups' unless token

    @lru_cache.insert(token, packed_data, ttl, silence_read)

    token
  end

  def self.create(data, ttl: nil, silence_read: nil)
    if CRUDJT::Config.master?
      CRUDJT.original_create(data, ttl: ttl, silence_read: silence_read)
    else
      # token_service.proto expect int64/32 values
      # it sensative for nil and covert it to 0
      ttl ||= -1
      silence_read ||= -1

      CRUDJT::Config.stub.create_token(Token::CreateTokenRequest.new(packed_data: MessagePack.pack(data), ttl: ttl, silence_read: silence_read)).token
    end
  end

  def self.original_read(token)
    raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_NOT_STARTED) unless CRUDJT::Config.was_started
    CRUDJT::Validation.validate_token!(token)

    output = @lru_cache.get(token)
    return output if output

    str = __read(token)
    return if str.nil?

  	result = JSON.parse(str)
    raise CRUDJT::ERRORS[result['code']] unless result['ok']
    return if result['data'].nil?

    data = JSON(result['data'])
    @lru_cache.force_insert(token, data)
    data
  end

  def self.read(token)
    if CRUDJT::Config.master?
      CRUDJT.original_read(token)
    else
      resp = CRUDJT::Config.stub.read_token(Token::ReadTokenRequest.new(token: token))

      MessagePack.unpack(resp.packed_data)
    end
  end

  def self.original_update(token, hash, ttl: nil, silence_read: nil)
    raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_NOT_STARTED) unless CRUDJT::Config.was_started
    CRUDJT::Validation.validate_token!(token)
    CRUDJT::Validation.validate_insertion!(hash, ttl, silence_read)

    packed_data = MessagePack.pack(hash)
    hash_bytesize = packed_data.bytesize
    CRUDJT::Validation.validate_hash_bytesize!(hash_bytesize)

    ttl ||= -1
    silence_read ||= -1

    # Creation buffer with packed data
    buffer = FFI::MemoryPointer.new(:char, hash_bytesize)
    buffer.put_bytes(0, packed_data)

    result = __update(token, buffer, hash_bytesize, ttl, silence_read)
    if result
      @lru_cache.delete(token)
      @lru_cache.insert(token, packed_data, ttl, silence_read)
    end
    result
  end

  def self.update(token, data, ttl: nil, silence_read: nil)
    if CRUDJT::Config.master?
      CRUDJT.original_update(token, data, ttl: ttl, silence_read: silence_read)
    else
      # token_service.proto expect int64/32 values
      # it sensative for nil and covert it to 0
      ttl ||= -1
      silence_read ||= -1

      CRUDJT::Config.stub.update_token(Token::UpdateTokenRequest.new(token: token, packed_data: MessagePack.pack(data), ttl: ttl, silence_read: silence_read)).result
    end
  end

  def self.original_delete(token)
    raise CRUDJT::Validation.error_message(CRUDJT::Validation::ERROR_NOT_STARTED) unless CRUDJT::Config.was_started
    CRUDJT::Validation.validate_token!(token)

    @lru_cache.delete(token)
    __delete(token)
  end

  def self.delete(token)
    if CRUDJT::Config.master?
      original_delete(token)
    else
      CRUDJT::Config.stub.delete_token(Token::DeleteTokenRequest.new(token: token)).result
    end
  end
end
