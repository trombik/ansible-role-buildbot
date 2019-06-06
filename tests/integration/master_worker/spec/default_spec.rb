require "spec_helper"

class ServiceNotReady < StandardError
end

sleep 10 if ENV["JENKINS_HOME"]

context "after provisioning finished" do
  describe server(:worker1) do
    it "should be able to ping server" do
      result = current_server.ssh_exec("ping -c 1 #{server(:server1).server.address} && echo OK")
      expect(result).to match(/OK/)
    end

    it "fetch web interface top page" do
      r = current_server.ssh_exec("fetch -vv http://#{server(:server1).server.address}:8010")
      expect(r).to match(Regexp.escape("HTTP/1.1 200 OK"))
    end

    it "has pip-2.7 installed" do
      r = current_server.ssh_exec("pip-2.7 --version")
      expect(r).to match(/pip \d+\.\d+\.\d+\b/)
    end

    it "has platformio installed" do
      r = current_server.ssh_exec("sudo -H -u buildbot pip-2.7 list")
      expect(r).to match(/^platformio\b/)
    end

    it "has gcc48 installed" do
      r = current_server.ssh_exec("pkg info gcc48")
      expect(r).to match(/^gcc48-/)
    end

    it "has pio" do
      r = current_server.ssh_exec("sudo -u buildbot /usr/local/buildbot_worker/.local/bin/pio --version")
      expect(r).to match(/^PlatformIO/)
    end
  end

  describe server(:server1) do
    it "should be able to ping client" do
      result = current_server.ssh_exec("ping -c 1 #{server(:worker1).server.address} && echo OK")
      expect(result).to match(/OK/)
    end
  end
end
