class TokenServiceImpl < Token::TokenService::Service
  def self.call(port)
    server = GRPC::RpcServer.new
    server.add_http2_port(port, :this_port_is_insecure)
    server.handle(TokenServiceImpl)

    server
  end

  def create_token(request, _unused_call)
    packed_data = MessagePack.unpack(request.packed_data)
    ttl = request.ttl
    silence_read = request.silence_read

    # token_service.proto expect int64/32 values
    # it sensative for nil and covert it to 0
    ttl = nil if ttl == -1
    silence_read = nil if silence_read == -1

    token = CRUD_JT.original_create(packed_data, ttl: ttl, silence_read: silence_read)

    Token::CreateTokenResponse.new(token: token)
  end

  def read_token(request, _unused_call)
    raw_token = request.token
    result_hash = CRUD_JT.original_read(raw_token)
    packed_data = MessagePack.pack(result_hash)

    Token::ReadTokenResponse.new(packed_data: packed_data)
  end

  def update_token(request, _unused_call)
    raw_token = request.token
    packed_data = MessagePack.unpack(request.packed_data)

    ttl = request.ttl
    silence_read = request.silence_read

    # token_service.proto expect int64/32 values
    # it sensative for nil and covert it to 0
    ttl = nil if ttl == -1
    silence_read = nil if silence_read == -1

    result = CRUD_JT.original_update(raw_token, packed_data, ttl: ttl, silence_read: silence_read)

    Token::UpdateTokenResponse.new(result: result)
  end

  def delete_token(request, _unused_call)
    raw_token = request.token

    result = CRUD_JT.original_delete(raw_token)

    Token::DeleteTokenResponse.new(result: result)
  end
end
