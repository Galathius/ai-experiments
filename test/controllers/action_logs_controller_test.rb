require "test_helper"

class ActionLogsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get action_logs_index_url
    assert_response :success
  end
end
