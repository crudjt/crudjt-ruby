<p align="center">
  <img src="logos/crud_jt_logo_black.png#gh-light-mode-only" alt="Logo Light" />
  <img src="logos/crud_jt_logo.png#gh-dark-mode-only" alt="Logo Dark" />
</p>

<p align="center">
  Simplifies user session. Login/Logout/Authorization
</p>

<p align="center">
  <a href="https://www.patreon.com/crudjt">
    <img src="logos/buy_me_a_coffee_orange.svg" alt="Buy Me a Coffee"/>
  </a>
</p>

# Installation

```sh
bundle add crudjt
```
Or install directly  
```sh
gem install crudjt
```

Require CRUDJT in your project

```ruby
require 'crudjt'

# openssl rand -base64 48 # In your terminal
# => your_encrypted_base64/48
CRUD_JT::Config.encrypted_key('your_encrypted_base64/32/48/64')
               .store_jt_path('your_path_to_file_storage') # optional
               .start!
```

# C

```ruby
CRUD_JT.create({ user_id: 42, role: 11 })
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

```ruby
# with :ttl — token time-to-live in seconds
CRUD_JT.create({ user_id: 42, role: 11 }, ttl: 3600 * 24 * 30)
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

# R

```ruby
# ...
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"data"=>{"user_id"=>42, "role"=>11}}
```

```ruby
# with :ttl
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

# U

```ruby
CRUD_JT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 8 })
=> true # {"data"=>{"user_id"=>42, "role"=>8}}
```

```ruby
# supported :ttl update
CRUD_JT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 8 }, ttl: 42)
=> true # {"metadata"=>{"ttl"=>42}, "data"=>{"user_id"=>42, "role"=>8}}
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
**40k** requests of **256 bytes** — median over 10 runs  
ARM64 (Apple M1+), macOS 15.5/15.6  
Ruby 3.4.4

| Function | CRUDJT (Ruby) | JWT (Ruby) | redis-session-store (Ruby, Rails 8.0.4) |
|----------|-------|------|------|
| C        | `0.34 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | 0.641 second | 4.057 seconds |
| R        | `0.144 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | 1.019 second | 7.011 seconds |
| U        | `0.46 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | X | 3.49 seconds |
| D        | `0.194 second` ![Logo Favicon Light](logos/crud_jt_logo_favicon_white.png#gh-light-mode-only) ![Logo Favicon Dark](logos/crud_jt_logo_favicon_black.png#gh-dark-mode-only) | X | 6.589 seconds |

[Full results](https://github.com/exwarvlad/benchmarks)

# Storage (Store JT)

## Path Lookup Order
Stored tokens are placed in the **file system** according to the following order

1. Explicitly set via `CRUD_JT::Config.store_jt_path('custom/path/to/file_system_db')`
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
require "crudjt"

# Required configuration
CRUD_JT::Config.encrypted_key("some_base64_key")

# Optional configuration
CRUD_JT::Config.store_jt_path("/custom/path/to/store_jt")

# Start the CRUDJT and Store JT
CRUD_JT::Config.start!
```


#### `encrypted_key(base64_key)`
Sets the encrypted key (**required**)

#### `store_jt_path(path_to_db)`
Overrides the default Store JT path (**optional**)

#### `start!`
Initializes the CRUDJT and opens the Store JT (**must be called last**)

# Limits
The library has the following limits and requirements

- **Ruby version:** tested with 2.7
- **Supported platforms:** Linux, macOS, Windows (x86_64 / arm64)
- **Maximum json size per token:** 256 bytes
- **`encrypted_key` format:** must be Base64
- **`encrypted_key` size:** must be 32, 48, or 64 bytes

# Contact & Support
<p align="center">
  <img src="logos/crud_jt_logo_favicon_black_160.png#gh-light-mode-only" alt="Visit Light" />
  <img src="logos/crud_jt_logo_favicon_white_160.png#gh-dark-mode-only" alt="Visit Dark" />
</p>

- **Custom integrations / new features / collaboration**: support@crudjt.com  
- **Library support & bug reports:** [open an issue](https://github.com/crudjt/crudjt-ruby/issues)


# Lincense
CRUDJT is released under the [MIT License](LICENSE.txt)

<p align="center">
  💘 Shoot your g . ? Love me out via <a href="https://www.patreon.com/crudjt">Patreon Sponsors</a>!
</p>
