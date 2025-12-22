require 'benchmark'
require 'crudjt'

p "OS: #{RbConfig::CONFIG['host_os']}"
p "CPU: #{RbConfig::CONFIG['host_cpu']}"

p 'Checking encrypted key validations...'
# when started without encrypted key
begin
  CRUD_JT::Config.start_master
rescue RuntimeError => error
  p error.message == CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_ENCRYPTED_KEY_NOT_SET)
else
  p false
end

# when started with fake base64 encrypted key
begin
  CRUD_JT::Config.start_master(encrypted_key: 'bla-bla-bla')
rescue ArgumentError => error
  p error.message == "'encrypted_key' must be a valid Base64 string"
else
  p false
end

# when started with wrong encrypted key lenght
begin
  key_16_bytes = '2v+XIslTkPTfjva0xeCLHQ=='
  CRUD_JT::Config.start_master(encrypted_key: key_16_bytes)
rescue ArgumentError => error
  p error.message == "'encrypted_key' must be exactly 32, 48, or 64 bytes. Got #{Base64.strict_decode64(key_16_bytes).bytesize} bytes"
else
  p false
end

p 'Checking base validations...'

# when not started store_jt
begin
  CRUD_JT.original_create({ some_key: 'some value' })
rescue RuntimeError => error
  p error.message == CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_NOT_STARTED)
else
  p false
end

# when broken store_jt path
begin
  CRUD_JT::Config.start_master(
    encrypted_key: 'Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==',
    store_jt_path: '/qweqe/qwrqwrrqt'
  )
rescue CRUD_JT::Errors::InternalError => _
  # p error.message == 'DB init error: Database opening failed: IO error: Read-only file system (os error 30)'
  p true
else
  p false unless RbConfig::CONFIG['host_os'].include?('w32')
end
    # when not started store_jt
    begin
      CRUD_JT.original_create({ some_key: 'some value' })
    rescue RuntimeError => error
      p error.message == CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_NOT_STARTED)
    else
      p false unless RbConfig::CONFIG['host_os'].include?('w32')
    end

begin
  CRUD_JT::Config.start_master(
    encrypted_key: 'Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==',
    store_jt_path: '/var/lib/store_jt'
  )
rescue => e
  p e.message unless RbConfig::CONFIG['host_os'].include?('w32')
end

CRUD_JT::Config.start_master(
  encrypted_key: 'Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=='
)

p "Master: #{CRUD_JT::Config.master?}"

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
  hash_with_unlim_size = { some_key: 'q' * CRUD_JT::Validation::MAX_HASH_SIZE }
  hash_bytesize = MessagePack.pack(hash_with_unlim_size).bytesize

  while MessagePack.pack(hash_with_unlim_size).bytesize > CRUD_JT::Validation::MAX_HASH_SIZE + 1
    hash_with_unlim_size[:some_key].chop!
  end

  CRUD_JT.create(hash_with_unlim_size)
rescue RuntimeError => error
  p error.message == "Hash can not be bigger than #{CRUD_JT::Validation::MAX_HASH_SIZE} bytesize"
else
  p false
end

# describe encrypted_key
# when started
begin
  CRUD_JT::Config.start_master
rescue RuntimeError => error
  p error.message == CRUD_JT::Validation.error_message(CRUD_JT::Validation::ERROR_ALREADY_STARTED)
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
p "Checking silence read..."

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
while MessagePack.pack(data).bytesize > CRUD_JT::Validation::MAX_HASH_SIZE
  data[:a].chop!
end

updated_data = { user_id: 42, role: 11 }

p "Hash bytesize: #{MessagePack.pack(data).bytesize}"
values = []
10.times do
  tokens = []

  p 'Checking scale load...'

  # when create
  p 'when creates 40k tokens with Turbo Queue'
  puts Benchmark.measure { REQUESTS.times { |i| tokens << CRUD_JT.create(data) } }

  # when read
  p 'when reads 40k tokens'
  index = rand(0..REQUESTS)
  puts Benchmark.measure { REQUESTS.times { |i| CRUD_JT.read(tokens[i]) } }

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
