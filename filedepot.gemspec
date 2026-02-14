# frozen_string_literal: true

require_relative "lib/filedepot/version"

Gem::Specification.new do |spec|
  spec.name          = "filedepot"
  spec.version       = Filedepot::VERSION
  spec.authors       = ["Filedepot"]
  spec.email         = [""]

  spec.summary       = "Sync files on remote storage"
  spec.description   = "Command-line tool to sync files on remote storage via SSH"
  spec.homepage      = "https://github.com/magnum/filedepot"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{bin,lib}/**/*", "LICENSE", "README.md"].select { |f| File.file?(f) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "net-scp", "~> 4.0"
  spec.add_runtime_dependency "net-ssh", "~> 7.0"
  spec.add_runtime_dependency "thor", "~> 1.3"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
