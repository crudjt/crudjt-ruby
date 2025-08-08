require_relative 'lib/crud_jt/version'

Gem::Specification.new do |spec|
  spec.name          = "crud_jt"
  spec.version       = CrudJt::VERSION
  spec.authors       = ["v_akymov"]
  spec.email         = ["exwarvlad@gmail.com"]

  spec.summary       = %q{42}
  spec.description   = %q{42}
  spec.homepage      = "https://crud_jt.com"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = 'http://mygemserver.com'
  spec.metadata["source_code_uri"] = 'http://mygemserver.com'
  spec.metadata["changelog_uri"] = 'http://mygemserver.com'

  spec.add_dependency "ffi"
  spec.add_dependency 'msgpack'
  spec.add_dependency "lru_redux"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
