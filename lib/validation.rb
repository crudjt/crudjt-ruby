module Validation
  U64_MAX = 2**64 - 1

  def validate_insertion!(hash, ttl, silence_read)
    raise "Must be Hash" unless hash.is_a?(Hash)
    raise "ttl sould be grater then 0 and less then 2 power 64" if ttl && !ttl.between?(1, U64_MAX)
    raise "silence_read sould be grater then 0 and less then 2 power 64" if silence_read && !silence_read.between?(1, U64_MAX)
  end

  def validate_token!(token)
    raise "Token must be String" unless token.is_a?(String)
    raise "Token cant be blank" if token.size < 1
  end
end
