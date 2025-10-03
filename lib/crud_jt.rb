require 'ffi'
require 'json'
require 'msgpack'

require_relative 'lru_cache'
require_relative 'validation'
require_relative 'errors'

include CRUD_JT::Validation

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

module CRUD_JT
  extend FFI::Library

  load_store_jt_library

  module Config
    extend FFI::Library

    load_store_jt_library

    attach_function :start_store_jt, [:string, :string], :string

    @settings = {}

    class << self
      def check_encrypted_key
        @settings[:encrypted_key]
      end

      def encrypted_key(value)
        CRUD_JT::Validation.validate_encrypted_key!(value)

        @settings[:encrypted_key] = value
        self
      end

      def store_jt_path(value)
        @settings[:store_jt_path] = value
        self
      end

      def was_started
        @was_started
      end

      def start!
        raise CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_ENCRYPTED_KEY_NOT_SET) unless @settings[:encrypted_key]
        raise CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_ALREADY_STARTED) if was_started

        result = JSON(start_store_jt(@settings[:encrypted_key], @settings[:store_jt_path]))
        raise CRUD_JT::ERRORS[result['code']], result['error_message'] unless result['ok']

        @was_started = true
      end
    end
  end

  attach_function :__create, [:pointer, :size_t, :int, :int], :string
  attach_function :__read, [:string], :string
  attach_function :__update, [:string, :pointer, :size_t, :int, :int], :bool
  attach_function :__delete, [:string], :bool

  @lru_cache = CRUD_JT::LRUCache.new(lambda { |token| __read(token) })

  def self.create(hash, ttl: nil, silence_read: nil)
    raise CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_NOT_STARTED) unless CRUD_JT::Config.was_started
    CRUD_JT::Validation.validate_insertion!(hash, ttl, silence_read)

    ttl ||= -1
    silence_read ||= -1

    packed_data = MessagePack.pack(hash)
    hash_bytesize = packed_data.bytesize
    CRUD_JT::Validation.validate_hash_bytesize!(hash_bytesize)

    # Creation buffer with packed data
    buffer = FFI::MemoryPointer.new(:char, hash_bytesize)
    buffer.put_bytes(0, packed_data)

    token = __create(buffer, hash_bytesize, ttl, silence_read)
    raise CRUD_JT::CRUD_JT::ERRORS::InternalError, 'Something went wrong. Ups' unless token

    @lru_cache.insert(token, packed_data, ttl, silence_read)

    token
  end

  def self.read(token)
    raise CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_NOT_STARTED) unless CRUD_JT::Config.was_started
    CRUD_JT::Validation.validate_token!(token)

    output = @lru_cache.get(token)
    return output if output

    str = __read(token)
    return if str.nil?

  	result = JSON.parse(str)
    raise CRUD_JT::ERRORS[result['code']] unless result['ok']
    return if result['data'].nil?

    data = JSON(result['data'])
    @lru_cache.force_insert(token, data)
    data
  end

  def self.update(token, hash, ttl: nil, silence_read: nil)
    raise CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_NOT_STARTED) unless CRUD_JT::Config.was_started
    CRUD_JT::Validation.validate_token!(token)
    CRUD_JT::Validation.validate_insertion!(hash, ttl, silence_read)

    packed_data = MessagePack.pack(hash)
    hash_bytesize = packed_data.bytesize
    CRUD_JT::Validation.validate_hash_bytesize!(hash_bytesize)

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

  def self.delete(token)
    raise CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_NOT_STARTED) unless CRUD_JT::Config.was_started
    CRUD_JT::Validation.validate_token!(token)

    @lru_cache.delete(token)
    __delete(token)
  end
end
