require_relative 'lib/crudjt/version'

Gem::Specification.new do |spec|
  spec.name          = "crudjt"
  spec.version       = CRUDJT::VERSION
  spec.authors       = ["Vlad Akymov (v_akymov)"]
  spec.email         = ["support@crudjt.com"]

  spec.summary       = %q{Fast B-tree–backed token store for stateful sessions}
  spec.description = <<~DESC
    Fast B-tree–backed token store for stateful user sessions
    Provides authentication and authorization across multiple processes
    Optimized for vertical scaling on a single server
  DESC
  spec.homepage      = "https://github.com/crudjt"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/crudjt/crudjt-ruby"
  spec.metadata["documentation_uri"] = "https://github.com/crudjt/crudjt-ruby#readme"
  spec.metadata["changelog_uri"] = "https://github.com/crudjt/crudjt-ruby/blob/master/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/crudjt/crudjt-ruby/issues"
  spec.metadata["funding_uri"] = "https://patreon.com/crudjt"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["keywords"] = "auth, authentication, token, sessions, crud"

  spec.add_dependency "ffi", "~> 1.17"
  spec.add_dependency "msgpack", "~> 1.8"
  spec.add_dependency "lru_redux", "~> 1.1"
  spec.add_dependency "grpc", "~> 1.78.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
