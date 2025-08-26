<p align="center">
  <img src="logos/crud_jt_logo_black.png#gh-light-mode-only" alt="Logo Light" />
  <img src="logos/crud_jt_logo.png#gh-dark-mode-only" alt="Logo Dark" />
</p>

<p align="center">
  Simplifies user session. Login/Logout/Authorization
</p>

<p align="center">
  <a href="https://github.com/sponsors/exwarvlad">
    <img src="logos/buy_me_a_coffee_orange.svg" alt="Buy Me a Coffee"/>
  </a>
</p>

# Installation

```sh
bundle add crud_jt
```
Or install directly  
```sh
gem install crud_jt
```

Require CRUD JT in your project

```ruby
require 'crud_jt'

# openssl rand -base64 48 # In your terminal
# => your_encrypted_base64/48
CRUD_JT::Config.encrypted_key('your_encrypted_base64/32/48/64')
               .start!
```

# C

```ruby
CRUD_JT.create({ user_id: 42, role: 11 })
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

```ruby
# with ttl. Token's time to live in seconds
CRUD_JT.create({ user_id: 42, role: 11 }, ttl: 3600 * 24 * 30)
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

```ruby
# with silence_read. Silently reads the token a specified number of times and then permanently deletes it
CRUD_JT.create({ user_id: 42, role: 11 }, silence_read: 3)
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

```ruby
# with ttl and silence_read
CRUD_JT.create({ user_id: 42, role: 11 }, ttl: 3600 * 24 * 30, silence_read: 3)
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

# R

```ruby
# ...
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"data"=>{"user_id"=>42, "role"=>11}}
```

```ruby
# with ttl
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"ttl"=>3}, "data"=>{"user_id"=>42, "role"=>11}}

# after 1 second
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"ttl"=>2}, "data"=>{"user_id"=>42, "role"=>11}}

# still second
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"ttl"=>1}, "data"=>{"user_id"=>42, "role"=>11}}

# ups
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> nil
```

```ruby
# with silence_read
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"silence_read"=>2}, "data"=>{"user_id"=>42, "role"=>11}}

# after 1 read
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"silence_read"=>1}, "data"=>{"user_id"=>42, "role"=>11}}

# still one read
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"silence_read"=>0}, "data"=>{"user_id"=>42, "role"=>11}}

# ups
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> nil
```

```ruby
# with ttl and silence_read
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"ttl"=>88 "silence_read"=>2}, "data"=>{"user_id"=>42, "role"=>11}}
# ...
```

# U

```ruby
CRUD_JT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 8 })
=> true # {"data"=>{"user_id"=>42, "role"=>8}}
```

```ruby
# supports for ttl and/or silence_read
CRUD_JT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 6 }, ttl: 41, silence_read: 8)
=> true # {"metadata"=>{"ttl"=>41, "silence_read"=>10}, "data"=>{"user_id"=>42, "role"=>8}}
```

```ruby
# when expired/not found token
CRUD_JT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 8 })
=> false
```

# D
```ruby
# when token exist
CRUD_JT.delete("HBmKFXoXgJ46mCqer1WXyQ")
=> true
```

```ruby
# when expired/not found token
CRUD_JT.delete("HBmKFXoXgJ46mCqer1WXyQ")
=> false
```

# Performance
**40k** requests with **256 bytes** for each token  
Processor ARM64 (M1 +)

|         | C | R | U | D |
|----     |----|----|----|----|
| CRUD JT (Ruby) | 0.3 second | 0.05 second | 0.3 second | 0.2 second |
| JWT (C)     | 1.1 seconds | 2.8 seconds | X | X |
| redis-session (Rust)  | 1.0 second | 0.05 second | 0.05 second  | 0.05 second |
| Typical encryption algorithm (C)  | 1.0 second | 2.8 seconds | X | X |

[Benchmark tests repo]

# Storage (Store JT)

## Path Lookup Order
Stored tokens are placed in the **file system** according to the following order

1. Explicitly set via `CRUD_JT::Config.store_jt_path(...)`
2. Default system location
   - **Linux**: `/var/lib/store_jt`
   - **macOS**: `/usr/local/var/store_jt`
   - **Windows**: `C:\Program Files\store_jt`
3. Project root directory (fallback)

## Storage Characteristics
* Store JT **automatically removing expired tokens** every 24 hours without blocking the main thread   
* **Store JT automatically fsyncs every 500ms**, meanwhile tokens ​​are available from cache
* Store JT is available for one process to open per instance for the time being

## Configuration

You can configure the library before starting it

```ruby
require "crud_jt"

# Required configuration
CRUD_JT.encrypted_key("some_base64_key")

# Optional configuration
CRUD_JT.store_jt_path("/custom/path/to/store_jt")

# Start the CRUD JT and Store JT
CRUD_JT.start!
```


#### `encrypted_key(base64_key)`
Sets the encrypted key (**required**)

#### `store_jt_path(path_to_db)`
Overrides the default Store JT path (**optional**)

#### `start!`
Initializes the CRUD JT and opens the Store JT (**must be called last**)

# Limits
The library has the following limits and requirements

- **Ruby version:** tested with 2.7
- **Supported platforms:** Linux, macOS, Windows (x86_64 / arm64)
- **Maximum json size per token:** 256 bytes
- **`encrypted_key` format:** must be Base64
- **`encrypted_key` size:** must be 32, 48, or 64 bytes

# Contact & Support
![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only)
![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only)
Egineered by [EXWARVLAD](https://github.com/exwarvlad)

- **Custom integrations / new features / collaboration**: exwarvlad@gmail.com  
- **Library support & bug reports:** [open an issue](https://github.com/exwarvlad/crud_jt-ruby/issues)


# Lincense
CRUD JT is released under the [MIT License](https://opensource.org/licenses/MIT)

<p align="center">
  💘 Shoot your g . ? Love me out via <a href="https://github.com/sponsors/exwarvlad">Github Sponsors</a>!
</p>
