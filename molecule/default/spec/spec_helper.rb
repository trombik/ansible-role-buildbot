require "serverspec"
require "net/ssh"
require "tempfile"

set :backend, :ssh

if ENV["ASK_SUDO_PASSWORD"]
  begin
    require "highline/import"
  rescue LoadError
    raise "highline is not available. Try installing it."
  end
  set :sudo_password, ask("Enter sudo password: ") { |q| q.echo = false }
else
  set :sudo_password, ENV["SUDO_PASSWORD"]
end

host = ENV["TARGET_HOST"]

vagrant_dir = ENV["MOLECULE_EPHEMERAL_DIRECTORY"]
unless vagrant_dir
  raise "MOLECULE_EPHEMERAL_DIRECTORY environment variable is not set\n" \
    "Please run `rake spec` from molecule"
end

config = Tempfile.new("", Dir.tmpdir)
Bundler.with_original_env do
  Dir.chdir(vagrant_dir) do
    config.write(`vagrant ssh-config #{host}`)
  end
end
config.close

options = Net::SSH::Config.for(host, [config.path])

options[:user] = "vagrant"

set :host,        options[:host_name] || host
set :ssh_options, options

# Disable sudo
# set :disable_sudo, true

# Set environment variables
set :env, LANG: "C", LC_MESSAGES: "C"

# Set PATH
# set :path, '/sbin:/usr/local/sbin:$PATH'
