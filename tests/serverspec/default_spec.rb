require "spec_helper"
require "serverspec"

package = case os[:family]
          when "freebsd"
            "devel/py-buildbot"
          when "ubuntu"
            "python3-buildbot"
          when "redhat"
            nil
          else
            "buildbot"
          end
extra_packages = case os[:family]
                 when "freebsd"
                   ["devel/py-buildbot-www", "devel/py-buildbot-console-view", "devel/py-buildbot-grid-view", "devel/py-buildbot-waterfall-view"]
                 when "ubuntu"
                   ["python3-pip"]
                 when "redhat"
                   ["python36-pip", "openssl-devel"]
                 end
pip_packages = case os[:family]
               when "ubuntu"
                 ["buildbot-www", "buildbot-waterfall-view", "buildbot-console-view", "buildbot-grid-view"]
               when "redhat"
                 ["buildbot", "buildbot-www", "buildbot-waterfall-view", "buildbot-console-view", "buildbot-grid-view"]
               else
                 []
               end
service = case os[:family]
          when "ubuntu"
            "buildmaster@default"
          else
            "buildbot"
          end
service_proxy = "haproxy"
user    = "buildbot"
group   = "buildbot"
ports   = [8010]
root_dir = case os[:family]
           when "freebsd"
             "/usr/local/buildbot"
           else
             "/var/lib/buildbot"
           end
master_dir = case os[:family]
             when "ubuntu"
               "#{root_dir}/masters/default"
             when "freebsd", "redhat"
               root_dir.to_s
             end
config = "#{master_dir}/master.cfg"
default_user = "root"
default_group = case os[:family]
                when "freebsd", "openbsd"
                  "wheel"
                else
                  "root"
                end

base_url = "http://localhost:8000"
buildbot_users = [
  { name: "admin", password: "password" },
  { name: "guest", password: "guest" }
]

unless package.nil?
  describe package(package) do
    it { should be_installed }
  end
end

extra_packages.each do |p|
  describe package p do
    it { should be_installed }
  end
end

pip_packages.each do |p|
  describe package p do
    it { should be_installed.by("pip3") }
  end
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
when "ubuntu"
  describe file("/etc/default/buildbot") do
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

describe service service_proxy do
  it { should be_running }
  it { should be_enabled }
end

buildbot_users.each do |u|
  describe command "curl -v --user #{u[:name].shellescape}:#{u[:password].shellescape} #{base_url.shellescape + '/'}" do
    its(:exit_status) { should eq 0 }
    its(:stderr) { should match(/#{Regexp.escape("HTTP/1.1 200 OK")}/) }
    its(:stdout) { should match(/Hello World CI/) }
  end
end

describe command "curl -v #{base_url.shellescape + '/'}" do
  its(:exit_status) { should eq 0 }

  its(:stderr) { should_not match(/#{Regexp.escape("HTTP/1.1 200 OK")}/) }
  its(:stderr) { should match(/#{Regexp.escape("HTTP/1.1 401 Unauthorized")}/) }
  its(:stdout) { should_not match(/Hello World CI/) }
  its(:stdout) { should match(/Unauthorized/) }
end
