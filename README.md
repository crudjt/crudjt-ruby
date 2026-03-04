<p align="center">
  <img src="logos/crud_jt_logo_black.png#gh-light-mode-only" alt="Logo Light" />
  <img src="logos/crud_jt_logo.png#gh-dark-mode-only" alt="Logo Dark" />
</p>

<p align="center">
  Fast, file-backed JSON token for REST APIs with multi-process support
</p>

<p align="center">
  <a href="https://www.patreon.com/crudjt">
    <img src="logos/buy_me_a_coffee_orange.svg" alt="Buy Me a Coffee"/>
  </a>
</p>

> ⚠️ Version 1.0.0-beta — production testing phase   
> API is stable. Feedback is welcome before the final 1.0.0 release

Fast B-tree–backed token store for stateful user sessions  
Provides authentication and authorization across multiple processes  
Optimized for vertical scaling on a single server  

# Installation

```sh
bundle add crudjt
```
Or install directly  
```sh
gem install crudjt
```

## How to use

- One process starts the master
- All other processes connect to it

## Start CRUDJT master (once)

Start the CRUDJT master when your application boots  

Only **one process** should do this  
The master is responsible for session state and coordination  

### Generate an encrypted key

```sh
export CRUDJT_ENCRYPTED_KEY=$(openssl rand -base64 48)
```

```ruby
require 'crudjt'

CRUDJT::Config.start_master(
  encrypted_key: ENV.fetch('CRUDJT_ENCRYPTED_KEY'),
  store_jt_path: 'path/to/local/storage', # optional
  grpc_host: '127.0.0.1', # default
  grpc_port: 50051 # default
)
```

The encrypted key must be the same for all processes

## Start CRUDJT master in Docker
> `docker-compose.yml` will be published after 1.0.0-beta Docker image builds

## Connect to an existing CRUDJT master

Use this in all other processes  

Typical examples:
- multiple local processes
- background jobs
- forked processes

```ruby
require 'crudjt'

CRUDJT::Config.connect_to_master(
  grpc_host: '127.0.0.1', # default
  grpc_port: 50051 # default
)
```

### Process layout

App boot  
 ├─ Process A → start_master  
 ├─ Process B → connect_to_master  
 └─ Process C → connect_to_master  

# C

```ruby
data = { user_id: 42, role: 11 } # required
ttl = 3600 * 24 * 30 # optional # Dynamic time to live token in seconds

# Optional # Each read decrements silence_read by 1, when the counter reaches
# zero — the token is deleted permanently
silence_read = 10

CRUDJT.create(data, ttl: ttl, silence_read: silence_read)
=> "HBmKFXoXgJ46mCqer1WXyQ"
```

# R

```ruby
CRUDJT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> {"metadata"=>{"ttl"=>101001, "silence_read"=>9}, "data"=>{"user_id"=>42, "role"=>11}}
```

```ruby
# when expired/not found token
CRUD_JT.read("HBmKFXoXgJ46mCqer1WXyQ")
=> nil
```

# U

```ruby
CRUDJT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 8 }, ttl: 600, silence_read: 100)
=> true # {"metadata"=>{"ttl"=>600, "silence_read"=>100}, "data"=>{"user_id"=>42, "role"=>8}}
```

```ruby
# when expired/not found token
CRUDJT.update("HBmKFXoXgJ46mCqer1WXyQ", { user_id: 42, role: 8 })
=> false
```

# D
```ruby
CRUDJT.delete("HBmKFXoXgJ46mCqer1WXyQ")
=> true
```

```ruby
# when expired/not found token
CRUDJT.delete("HBmKFXoXgJ46mCqer1WXyQ")
=> false
```

# Performance
> Metrics will be published after 1.0.0-beta GitHub Actions builds

# Storage (File-backed)  

## Disk footprint  
> Metrics will be published after 1.0.0-beta GitHub Actions builds

## Path Lookup Order
Stored tokens are placed in the **file system** according to the following order

1. Explicitly set via `CRUDJT::Config.start_master(store_jt_path: 'custom/path/to/file_system_db')`
2. Default system location
   - **Linux**: `/var/lib/store_jt`
   - **macOS**: `/usr/local/var/store_jt`
   - **Windows**: `C:\Program Files\store_jt`
3. Project root directory (fallback)

## Storage Characteristics
* CRUDJT **automatically removing expired tokens** after start and every 24 hours without blocking the main thread   
* **Storage automatically fsyncs every 500ms**, meanwhile tokens ​​are available from cache

# Multi-process Coordination
For multi-process scenarios, CRUDJT uses gRPC over an insecure local port for same-host communication only. It is not intended for inter-machine or internet-facing usage

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
