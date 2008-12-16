require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'sambala'
  s.version = '0.8.2'
  s.author = 'Louis-Philippe Perron'
  s.email = 'lp@spiralix.org'
  s.homepage = 'http://sambala.rubyforge.org/'
  s.rubyforge_project = 'Sambala'
  s.platform = Gem::Platform::RUBY
  s.summary = 'ruby samba client, interactive smbclient commands session and multi-threaded smb transfer queued mode'
  s.files = FileList["{lib,test}/**/*"].exclude("doc").to_a
  s.require_path = "lib"
  # s.test_file = "test/ts_abundance.rb"
  s.has_rdoc = true
  s.add_dependency("abundance", ">= 1.0.7")
end
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end
