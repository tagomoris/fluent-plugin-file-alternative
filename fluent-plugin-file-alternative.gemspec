# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-file-alternative"
  gem.version       = "0.1.1"

  gem.authors       = ["TAGOMORI Satoshi"]
  gem.email         = ["tagomoris@gmail.com"]
  gem.description   = %q{alternative implementation of out_file, with various configurations}
  gem.summary       = %q{alternative implementation of out_file}
  gem.homepage      = "https://github.com/tagomoris/fluent-plugin-file-alternative"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "fluentd"
  gem.add_runtime_dependency "fluentd"
end
