require 'base64'

module Validation
  U64_MAX = 2**64 - 1

  MIN_TTL = 1
  MIN_SILENCE_REAAD = 1

  MAX_HASH_SIZE = 256

  def validate_insertion!(hash, ttl, silence_read)
    raise "Must be Hash" unless hash.is_a?(Hash)
    raise "Hash can not be empty" if hash.empty?
    raise "ttl sould be grater then #{MIN_TTL - 1} and less then 2 power 64" if ttl && !ttl.between?(MIN_TTL, U64_MAX)
    raise "silence_read sould be grater then #{MIN_SILENCE_REAAD - 1} and less then 2 power 64" if silence_read && !silence_read.between?(MIN_SILENCE_REAAD, U64_MAX)
  end

  def validate_hash_bytesize!(hash_bytesize)
    raise "Hash can not be bigger than #{MAX_HASH_SIZE} bytesize" if hash_bytesize > MAX_HASH_SIZE
  end

  def validate_token!(token)
    raise "Token must be String" unless token.is_a?(String)
    raise "Token cant be blank" if token.size < 1
  end

  def validate_encrypted_key!(key)
    begin
      decoded = Base64.strict_decode64(key)
    rescue ArgumentError
      raise ArgumentError, "'encrypted_key' must be a valid Base64 string"
    end

    unless [32, 48, 64].include?(decoded.bytesize)
      raise ArgumentError, "'encrypted_key' must be exactly 32, 48, or 64 bytes. Got #{decoded.bytesize} bytes"
    end

    true
  end
end
