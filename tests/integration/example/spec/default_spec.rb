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
  end

  describe server(:server1) do
    it "should be able to ping client" do
      result = current_server.ssh_exec("ping -c 1 #{server(:worker1).server.address} && echo OK")
      expect(result).to match(/OK/)
    end
  end
end
