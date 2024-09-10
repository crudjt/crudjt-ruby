require 'lru_redux'

class LRUCache
  CACHE_CAPACITY = 40_000

  def initialize(read_func)
    @cache = LruRedux::ThreadSafeCache.new(CACHE_CAPACITY)
    @read_func = read_func
  end

  def get(token)
    cached_value = cache[token]

    if cached_value
      cached_value = deep_stringify_keys(cached_value) if cached_value[:data]
      cache[token] = cached_value
      output = {}

      if cached_value.dig('metadata', 'ttl')
        ttl = (cached_value['metadata']['ttl'] - Time.now).ceil
        if ttl <= 0
          cache.delete(token)
          return
        end

        output['metadata'] = {}
        output['metadata']['ttl'] = ttl
      end

      silence_read = cached_value.dig('metadata', 'silence_read')
      if silence_read
        silence_read = cached_value['metadata']['silence_read'] -= 1
        output['metadata'] ||= {}
        output['metadata']['silence_read'] = silence_read

        cache.delete(token) if silence_read <= 0
      end
      read_func.call(token) if silence_read
      output['data'] = cached_value['data']

      return output
    end
  end

  def insert(key, value, ttl, silence_read)
    hash = { data: value }

    if ttl > 0
      hash['metadata'] = {}
      hash['metadata']['ttl'] = (Time.now + ttl)
    end

    if silence_read > 0
      hash['metadata'] ||= {}
      hash['metadata']['silence_read'] = silence_read
    end

    cache[key] = hash
  end

  def force_insert(token, hash)
    cache[token] = hash
  end

  def delete(token)
    cache.delete(token)
  end

    private

    attr_reader :cache, :read_func

    def deep_stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        new_key = key.to_s
        new_value = value.is_a?(Hash) ? deep_stringify_keys(value) : value
        result[new_key] = new_value
      end
    end
end
