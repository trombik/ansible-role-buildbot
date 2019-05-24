require "spec_helper"
require "serverspec"

package = "buildbot"
service = "buildbot"
user    = "buildbot"
group   = "buildbot"
ports   = [8010]
root_dir = "/usr/local/buildbot/master"
config = "#{root_dir}/master.cfg"
default_user = "root"
default_group = "root"

case os[:family]
when "freebsd"
  default_group = "wheel"
  package = "devel/py-buildbot"
end

describe package(package) do
  it { should be_installed }
end

describe file root_dir do
  it { should exist }
  it { should be_directory }
  it { should be_mode 755 }
  it { should be_owned_by user }
  it { should be_grouped_into group }
end

describe file(config) do
  it { should exist }
  it { should be_file }
  it { should be_mode 640 }
  it { should be_owned_by user }
  it { should be_grouped_into group }
  its(:content) { should match(/from buildbot\.plugins import \*/) }
  its(:content) { should match(/Managed by ansible/) }
end

case os[:family]
when "freebsd"
  describe file("/etc/rc.conf.d/buildbot") do
    it { should exist }
    it { should be_file }
    it { should be_mode 644 }
    it { should be_owned_by default_user }
    it { should be_grouped_into default_group }
    its(:content) { should match(/Managed by ansible/) }
  end
end

describe service(service) do
  it { should be_running }
  it { should be_enabled }
end

ports.each do |p|
  describe port(p) do
    it { should be_listening }
  end
end
