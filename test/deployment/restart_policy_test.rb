require "test_helper"

# A service with no restart policy stays down after the Docker host reboots, and nothing
# in the app notices: Redis only backs Action Cable, so the site keeps serving pages while
# every scoreboard silently stops updating live. That happened on 1 Sep 2026, when Lofty
# rebooted and the Fringo instance's redis container stayed Exited for two weeks.
class RestartPolicyTest < ActiveSupport::TestCase
  test "every service comes back after the Docker host reboots" do
    services = YAML.load_file(Rails.root.join("docker-compose.yml")).fetch("services")

    services.each do |name, config|
      assert_includes %w[always unless-stopped], config["restart"],
                      "#{name} has no restart policy, so it stays down after a host reboot"
    end
  end
end
