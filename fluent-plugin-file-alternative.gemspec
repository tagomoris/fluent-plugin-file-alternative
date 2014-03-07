# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-file-alternative"
  gem.version       = "0.1.5"

  gem.authors       = ["TAGOMORI Satoshi"]
  gem.email         = ["tagomoris@gmail.com"]
  gem.description   = %q{alternative implementation of out_file, with various configurations}
  gem.summary       = %q{alternative implementation of out_file}
  gem.homepage      = "https://github.com/tagomoris/fluent-plugin-file-alternative"
  gem.license       = "APLv2"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "fluentd", ">= 0.10.39" # This version for @buffer.symlink_path
  gem.add_runtime_dependency "fluent-mixin-plaintextformatter"
  gem.add_development_dependency "rake"
end
