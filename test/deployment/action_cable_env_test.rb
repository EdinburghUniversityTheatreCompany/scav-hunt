require "test_helper"

# Nothing in the app can catch a malformed cable URL: config/cable.yml uses the test
# adapter, so the suite never dials the real endpoint, and a browser that cannot reach
# /cable just quietly stops receiving live updates. The one production incident this
# caused -- a bare hostname in ACTION_CABLE_FRONTEND_URL, which every browser resolved
# relative to the page it was on and turned into GET /scoring/<hostname> -- was only
# visible as routing errors in the logs. So the shape is asserted here, where it is
# decided: docker-compose.yml wrapping the bare host[:port] in HOST_URL.
class ActionCableEnvTest < ActiveSupport::TestCase
  setup do
    @environment = YAML.load_file(Rails.root.join("docker-compose.yml")).dig("services", "rails", "environment")
  end

  test "the cable url the browser is handed is absolute and points at the mount path" do
    url = @environment.fetch("ACTION_CABLE_FRONTEND_URL")

    assert_equal "wss", URI.parse(url.sub("${HOST_URL}", "example.test")).scheme,
                 "A scheme-less URL is resolved relative to the current page, not as a host"
    assert_equal "/cable", URI.parse(url.sub("${HOST_URL}", "example.test")).path,
                 "Action Cable is mounted at /cable (config/routes.rb)"
  end

  test "the allowed origin is a full origin, which is what the Origin header carries" do
    origin = @environment.fetch("ACTION_CABLE_ALLOWED_REQUEST_ORIGINS")

    # Action Cable compares this with `===` against env["HTTP_ORIGIN"], so a bare host
    # can never match and every connection would be refused.
    assert_equal "https://example.test", origin.sub("${HOST_URL}", "example.test")
  end
end
