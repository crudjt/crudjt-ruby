require 'benchmark'
# require_relative 'embed.rb'
require 'crud_jt'

p "OS: #{RbConfig::CONFIG['host_os']}"
p "CPU: #{RbConfig::CONFIG['host_cpu']}"

p 'Checking encrypted key validations...'
# when started without encrypted key
begin
  CRUD_JT::Config.start!
rescue RuntimeError => error
  p error.message == Validation.error_message(Validation::ERROR_ENCRYPTED_KEY_NOT_SET)
else
  p false
end

# when started with fake base64 encrypted key
begin
  CRUD_JT::Config.encrypted_key('bla-bla-bla').start!
rescue ArgumentError => error
  p error.message == "'encrypted_key' must be a valid Base64 string"
else
  p false
end

# when started with wrong encrypted key lenght
begin
  key_16_bytes = '2v+XIslTkPTfjva0xeCLHQ=='
  CRUD_JT::Config.encrypted_key(key_16_bytes).start!
rescue ArgumentError => error
  p error.message == "'encrypted_key' must be exactly 32, 48, or 64 bytes. Got #{Base64.strict_decode64(key_16_bytes).bytesize} bytes"
else
  p false
end

# validations
p 'Checking base validations...'

# when not started store_jt
begin
  CRUD_JT.create({ some_key: 'some value' })
rescue RuntimeError => error
  p error.message == Validation.error_message(Validation::ERROR_NOT_STARTED)
else
  p false
end

begin
  CRUD_JT::Config.encrypted_key('Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==')
                 .start!
rescue => e
  p e.message
end

# hash can not be empty
begin
  CRUD_JT.create({})
rescue RuntimeError => error
  p error.message == "Hash can not be empty"
else
  p false
end

# hash can not be bigger than maximum size
begin
  hash_with_unlim_size = { some_key: 'q' * Validation::MAX_HASH_SIZE }
  hash_bytesize = MessagePack.pack(hash_with_unlim_size).bytesize

  while MessagePack.pack(hash_with_unlim_size).bytesize > Validation::MAX_HASH_SIZE + 1
    hash_with_unlim_size[:some_key].chop!
  end

  CRUD_JT.create(hash_with_unlim_size)
rescue RuntimeError => error
  p error.message == "Hash can not be bigger than #{Validation::MAX_HASH_SIZE} bytesize"
else
  p false
end

# describe encrypted_key
# when started
begin
  CRUD_JT::Config.start!
rescue RuntimeError => error
  p error.message == Validation.error_message(Validation::ERROR_ALREADY_STARTED)
else
  p false
end

# with wrong token
p CRUD_JT.read('bla-bla-bla') == nil
p CRUD_JT.update('bla-bla-bla', { some_key: 41 }) == false
p CRUD_JT.delete('bla-bla-bla') == false


# without metadata
p 'Checking without metadata...'
data = { user_id: 42, role: 11 }
expected_data = { data: data.transform_keys(&:to_s) }.transform_keys(&:to_s)

updated_data = { user_id: 42, role: 8 }
expected_updated_data = { data: updated_data.transform_keys(&:to_s) }.transform_keys(&:to_s)

token = CRUD_JT.create(data)

p CRUD_JT.read(token) == expected_data
p CRUD_JT.update(token, updated_data) == true
p CRUD_JT.read(token) == expected_updated_data
p CRUD_JT.delete(token) == true
p CRUD_JT.read(token) == nil

# with ttl
p 'Checking ttl...'

data = { user_id: 42, role: 11 }

ttl = 5
token_with_ttl = CRUD_JT.create(data, ttl: ttl)

expected_ttl = ttl
ttl.times do |i|
  p CRUD_JT.read(token_with_ttl) == JSON.parse({ metadata: { ttl: expected_ttl }, data: data }.to_json)
  expected_ttl -= 1

  sleep 1
end
p CRUD_JT.read(token_with_ttl) == nil

# when expired ttl
p 'when expired ttl'
data = { user_id: 42, role: 11 }
ttl = 1
token = CRUD_JT.create(data, ttl: ttl)
sleep ttl
p CRUD_JT.read(token) == nil
p CRUD_JT.update(token, data) == false
p CRUD_JT.delete(token) == false

p CRUD_JT.update(token, data) == false
p CRUD_JT.read(token) == nil

# with silence read
p "Checkinh silence read..."

data = { user_id: 42, role: 11 }
silence_read = 6
token_with_silence_read = CRUD_JT.create(data, silence_read: silence_read)

expected_silence_read = silence_read - 1
silence_read.times do
  p CRUD_JT.read(token_with_silence_read) == JSON.parse({ metadata: { silence_read: expected_silence_read }, data: data }.to_json)
  expected_silence_read -= 1
end
p CRUD_JT.read(token_with_silence_read) == nil

# with ttl and silence read
p "Checking ttl and silence read..."

data = { user_id: 42, role: 11 }
ttl = 5
silence_read = ttl
token_with_ttl_and_silence_read = CRUD_JT.create(data, ttl: ttl, silence_read: silence_read)

expected_ttl = ttl
expected_silence_read = silence_read - 1
silence_read.times do
  p CRUD_JT.read(token_with_ttl_and_silence_read) == JSON.parse({ metadata: { ttl: expected_ttl, silence_read: expected_silence_read }, data: data }.to_json)
  expected_ttl -= 1
  expected_silence_read -= 1

  sleep 1
end
p CRUD_JT.read(token_with_ttl_and_silence_read) == nil

# with scale load

REQUESTS = 40_000

data = {user_id: 414243, role: 11, devices: {ios_expired_at: Time.now.to_s, android_expired_at: Time.now.to_s, external_api_integration_expired_at: Time.now.to_s}, a: "a" * 100 }
while MessagePack.pack(data).bytesize > Validation::MAX_HASH_SIZE
  data[:a].chop!
end

updated_data = { user_id: 42, role: 11 }

p "Hash bytesize: #{MessagePack.pack(data).bytesize}"
10.times do
  tokens = []

  p 'Checking scale load...'

  # when create
  p 'when creates 40k tokens with Turbo Queue'
  puts Benchmark.measure { REQUESTS.times { |i| tokens << CRUD_JT.create(data) } }

  # # puts CRUD_JT.read(tokens[0])
  #
  # when read
  p 'when reads 40k tokens'
  index = rand(0..REQUESTS)
  puts Benchmark.measure { REQUESTS.times { |i| CRUD_JT.read(tokens[index]) } }
  #
  # sleep 1
  #
  # # when reads randomly
  # # p "when reads randomly created token"
  # # index = rand(0...REQUESTS)
  # # 5.times { puts Benchmark.measure { REQUESTS.times { |i| CRUD_JT.read(tokens[index]) } } }
  # #
  # when updates
  p 'when updates 40k tokens'
  puts Benchmark.measure { REQUESTS.times { |i| CRUD_JT.update(tokens[i], updated_data) } }
  #
  # when delete
  p 'when deletes 40k tokens'
  puts Benchmark.measure { REQUESTS.times { |i| CRUD_JT.delete(tokens[i]) } }
end

# when cache after read from file system
p 'when caches after read from file system'

LIMIT_ON_READY_FOR_CACHE = 2

previus_tokens = []

REQUESTS.times { previus_tokens << CRUD_JT.create(data) }
REQUESTS.times { CRUD_JT.create(data) }

LIMIT_ON_READY_FOR_CACHE.times { puts Benchmark.measure { REQUESTS.times { |i| CRUD_JT.read(previus_tokens[i]) } } }
