require 'ffi'
require 'json'
require 'msgpack'

require_relative 'lru_cache'
require_relative 'validation'

include Validation

# require_relative 'methods/load_store_jt_library'

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

  attach_function :encrypted_key, [:string], :void

  attach_function :__create, [:pointer, :size_t, :int, :int], :string
  attach_function :__read, [:string], :string
  attach_function :__update, [:string, :pointer, :size_t, :int, :int], :bool
  attach_function :__delete, [:string], :bool

  @lru_cache = LRUCache.new(lambda { |token| __read(token) })

  def self.create(big_o_fucking_hash, ttl: nil, silence_read: nil)
    Validation.validate_insertion!(big_o_fucking_hash, ttl, silence_read)

    ttl ||= -1
    silence_read ||= -1

    packed_data = MessagePack.pack(big_o_fucking_hash)

    # Creation buffer with packed data
    buffer = FFI::MemoryPointer.new(:char, packed_data.bytesize)
    buffer.put_bytes(0, packed_data)

    token = __create(buffer, packed_data.bytesize, ttl, silence_read)

    @lru_cache.insert(token, big_o_fucking_hash, ttl, silence_read)

    token
  end

  def self.read(token)
    Validation.validate_token!(token)

    output = @lru_cache.get(token)
    return output if output

    str = __read(token)
    return if str.empty?

  	result = JSON.parse(str)
    result.size > 0 ? result : nil
  end

  def self.update(token, big_o_fucking_hash, ttl: nil, silence_read: nil)
    Validation.validate_token!(token)
    Validation.validate_insertion!(big_o_fucking_hash, ttl, silence_read)

    ttl ||= -1
    silence_read ||= -1

    @lru_cache.delete(token)
    @lru_cache.insert(token, big_o_fucking_hash, ttl, silence_read)

    packed_data = MessagePack.pack(big_o_fucking_hash)

    # Creation buffer with packed data
    buffer = FFI::MemoryPointer.new(:char, packed_data.bytesize)
    buffer.put_bytes(0, packed_data)

    __update(token, buffer, packed_data.bytesize, ttl, silence_read)
  end

  def self.delete(token)
    Validation.validate_token!(token)

    @lru_cache.delete(token)
    __delete(token)
  end

  encrypted_key('Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==')
end
