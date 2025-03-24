require 'test_plugin_helper'
require 'foreman_tasks/test_helpers'

class InsightsResolutionsSyncTest < ActiveSupport::TestCase
  include ForemanTasks::TestHelpers::WithInThreadExecutor
  include MockCerts

  setup do
    @resolutions = {
      "advisor:ansible_deprecated_repo|ANSIBLE_DEPRECATED_REPO" => {
        "id" => "advisor:ansible_deprecated_repo|ANSIBLE_DEPRECATED_REPO",
        "resolution_risk" => 1,
        "resolutions" => [
          {
            "description" => "Enable ansible repo and update ansible package",
            "id" => "fix",
            "needs_reboot" => false,
            "resolution_risk" => 1,
          },
        ],
      },
      "advisor:hardening_logging_auditd|HARDENING_LOGGING_5_AUDITD" => {
        "id" => "advisor:hardening_logging_auditd|HARDENING_LOGGING_5_AUDITD",
        "resolution_risk" => 1,
        "resolutions" => [
          {
            "description" => "Install and enable auditd",
            "id" => "fix",
            "needs_reboot" => false,
            "resolution_risk" => 1,
          },
        ],
      },
      "advisor:network_manager_dhcp_client_network_issue|NETWORK_MANAGER_DHCP_CLIENT_NETWORK_ISSUE" => {
        "id" => "advisor:network_manager_dhcp_client_network_issue|NETWORK_MANAGER_DHCP_CLIENT_NETWORK_ISSUE",
        "resolution_risk" => 1,
        "resolutions" => [
          {
            "description" => "Update the NetworkManager package to fix this issue",
            "id" => "fix",
            "needs_reboot" => false,
            "resolution_risk" => 1,
          },
        ],
      },
      "advisor:network_tcp_connection_hang|NETWORK_TCP_CONNECTION_HANG_WARN" => {
        "id" => "advisor:network_tcp_connection_hang|NETWORK_TCP_CONNECTION_HANG_WARN",
        "resolution_risk" => 3,
        "resolutions" => [
          {
            "description" => "Update system to the latest kernel and reboot",
            "id" => "kernel_update",
            "needs_reboot" => true,
            "resolution_risk" => 3,
          },
          {
            "description" => "Run in panic and scream",
            "id" => "panic",
            "needs_reboot" => true,
            "resolution_risk" => 10,
          },
        ],
      },
    }

    @rule = FactoryBot.create(:insights_rule, rule_id: 'network_tcp_connection_hang|NETWORK_TCP_CONNECTION_HANG_WARN')

    setup_certs_expectation do
      InsightsCloud::Async::InsightsResolutionsSync.any_instance.stubs(:candlepin_id_cert)
    end

    Organization.any_instance.stubs(:manifest_expired?).returns(false)
  end

  test 'Resolutions data is replaced with data from cloud' do
    Katello::UpstreamConnectionChecker.any_instance.stubs(:can_connect?).returns(true)
    InsightsCloud::Async::InsightsResolutionsSync.any_instance.stubs(:query_insights_resolutions).returns(@resolutions)

    ForemanTasks.sync_task(InsightsCloud::Async::InsightsResolutionsSync)
    @rule.reload

    assert_equal 5, InsightsResolution.all.count
    assert_equal 2, @rule.resolutions.count
  end

  test 'Manifest is deleted do not run task steps' do
    Organization.any_instance.stubs(:manifest_expired?).returns(false)
    Katello::UpstreamConnectionChecker.any_instance.stubs(:can_connect?).returns(false)
    InsightsCloud::Async::InsightsResolutionsSync.any_instance.expects(:query_insights_resolutions).never

    ForemanTasks.sync_task(InsightsCloud::Async::InsightsResolutionsSync)

    assert_equal 0, InsightsResolution.all.count
  end

  test 'Manifest is expired do not run task steps' do
    Organization.any_instance.stubs(:manifest_expired?).returns(true)
    Katello::UpstreamConnectionChecker.any_instance.stubs(:can_connect?).returns(true)
    InsightsCloud::Async::InsightsResolutionsSync.any_instance.expects(:query_insights_resolutions).never

    ForemanTasks.sync_task(InsightsCloud::Async::InsightsResolutionsSync)

    assert_equal 0, InsightsResolution.all.count
  end

  test 'Skips pinging the cloud if no rule ids were found' do
    Katello::UpstreamConnectionChecker.any_instance.stubs(:can_connect?).returns(true)
    InsightsCloud::Async::InsightsResolutionsSync.any_instance.expects(:query_insights_resolutions).never
    InsightsRule.all.delete_all

    ForemanTasks.sync_task(InsightsCloud::Async::InsightsResolutionsSync)

    assert_equal 0, InsightsResolution.all.count
  end
end
