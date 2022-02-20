require "spec_helper"

worker_dir = case os[:family]
             when "freebsd"
               "/usr/local/buildbot_worker"
             else
               raise "unsupported os[:family]: `#{os[:family]}`"
             end
worker_log_file = "#{worker_dir}/twistd.log"

describe service("sshd") do
  it { should be_enabled }
  it { should be_running }
end

describe port(22) do
  it { should be_listening }
end

describe file worker_log_file do
  it { should exist }
  it { should be_file }
  its(:content) { should match(/Connected to buildmaster/) }
end
