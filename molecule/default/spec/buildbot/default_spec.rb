require "spec_helper"

describe service("sshd") do
  it { should be_enabled }
  it { should be_running }
end

describe port(22) do
  it { should be_listening }
end
