require 'test_plugin_helper'
require 'foreman_tasks/test_helpers'

class QueueForUploadJobTest < ActiveSupport::TestCase
  include ForemanTasks::TestHelpers::WithInThreadExecutor
  include FolderIsolation

  let(:organization) { FactoryBot.create(:organization) }
  let(:base_folder) { @tmpdir }
  let(:report_file) { 'test_report.tar.xz' }
  let(:report_path) { File.join(base_folder, report_file) }
  let(:uploads_folder) { ForemanInventoryUpload.uploads_folder }

  setup do
    # Stub the script template source
    script_source = File.join(ForemanRhCloud::Engine.root, 'lib/foreman_inventory_upload/scripts/uploader.sh.erb')
    File.stubs(:read).with(script_source).returns('#!/bin/bash\necho "Test script"')

    # Stub template rendering
    Foreman::Renderer.stubs(:render).returns('#!/bin/bash\necho "Rendered script"')

    # Stub additional settings that are accessed
    Setting.stubs(:[]).with(:content_default_http_proxy).returns(nil)
    Setting.stubs(:[]).with(:subscription_connection_enabled).returns(true)
    Setting.stubs(:[]).with("foreman_tasks_sync_task_timeout").returns(120)
  end

  teardown do
    FileUtils.rm_rf(uploads_folder) if Dir.exist?(uploads_folder)
  end

  private

  def setup_disconnected_test(via_setting: false, disconnected_param: false)
    FileUtils.touch(report_path)
    Setting.stubs(:[]).with(:subscription_connection_enabled).returns(!via_setting)
    ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.stubs(:plan_upload_report)
    disconnected_param
  end

  def expect_contextual_log_message(times: 1)
    expected_message = "#{ForemanInventoryUpload::Async::QueueForUploadJob::DISCONNECTED_MESSAGE_TEMPLATE} Report: #{report_file}, Organization: #{organization.name}"
    mock_logger = mock('logger')
    mock_logger.expects(:info).with(expected_message).times(times)
    ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.stubs(:logger).returns(mock_logger)
    expected_message
  end

  test 'plan method sets up the job correctly and calls plan_upload_report when connected' do
    # Create a test report file for this test
    FileUtils.touch(report_path)

    organization_id = organization.id
    disconnected = false

    # Mock plan_upload_report to verify it's called
    ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.expects(:plan_upload_report).once

    task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization_id, disconnected)
    assert_equal 'success', task.result
  end

  test 'plan method does not call plan_upload_report when subscription connection disabled' do
    # Create a test report file for this test
    FileUtils.touch(report_path)

    Setting.stubs(:[]).with(:subscription_connection_enabled).returns(false)

    organization_id = organization.id
    disconnected = false

    # Mock plan_upload_report to verify it's NOT called
    ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.expects(:plan_upload_report).never

    task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization_id, disconnected)
    assert_equal 'success', task.result
  end

  test 'run method skips processing when content is disconnected via parameter' do
    disconnected = setup_disconnected_test(disconnected_param: true)
    task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization.id, disconnected)
    assert_equal 'success', task.result
  end

  test 'run method skips processing when subscription connection is disabled' do
    disconnected = setup_disconnected_test(via_setting: true)
    task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization.id, disconnected)
    assert_equal 'success', task.result
  end

  test 'run method processes file when connected' do
    # Create a test report file for this test
    FileUtils.touch(report_path)

    Setting.stubs(:[]).with(:subscription_connection_enabled).returns(true)

    ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.stubs(:plan_upload_report)

    task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization.id, false)
    assert_equal 'success', task.result

    # Verify the file was moved
    refute File.exist?(report_path), "Original file should be moved"
    assert File.exist?(File.join(uploads_folder, report_file)), "File should exist in uploads folder"
  end

  test 'handles disconnection properly and does not move files' do
    [
      { via_setting: true, disconnected_param: false, description: 'via subscription setting' },
      { via_setting: false, disconnected_param: true, description: 'via disconnected parameter' },
    ].each do |scenario|
      disconnected = setup_disconnected_test(via_setting: scenario[:via_setting], disconnected_param: scenario[:disconnected_param])

      task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization.id, disconnected)
      assert_equal 'success', task.result, "Task should succeed when disconnected #{scenario[:description]}"

      # Verify the file was NOT moved when disconnected
      assert File.exist?(report_path), "Original file should still exist when disconnected #{scenario[:description]}"
    end
  end

  test 'creates necessary folders and scripts when connected' do
    # Create a test report file for this test
    FileUtils.touch(report_path)

    Setting.stubs(:[]).with(:subscription_connection_enabled).returns(true)

    ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.stubs(:plan_upload_report)

    task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization.id, false)
    assert_equal 'success', task.result

    # Verify the uploads folder was created
    assert Dir.exist?(uploads_folder), "Uploads folder should be created"

    # Verify the script file was created
    script_path = File.join(uploads_folder, ForemanInventoryUpload.upload_script_file)
    assert File.exist?(script_path), "Upload script should be created"
  end

  test 'logs contextual disconnected message for different disconnection scenarios' do
    [
      { via_setting: true, disconnected_param: false, description: 'subscription setting disabled' },
      { via_setting: false, disconnected_param: true, description: 'disconnected parameter true' },
    ].each do |scenario|
      disconnected = setup_disconnected_test(via_setting: scenario[:via_setting], disconnected_param: scenario[:disconnected_param])
      expect_contextual_log_message(times: 2) # logged in both plan and run phases

      # Mock plan_upload_report to verify it's never called when disconnected
      ForemanInventoryUpload::Async::QueueForUploadJob.any_instance.expects(:plan_upload_report).never

      task = ForemanTasks.sync_task(ForemanInventoryUpload::Async::QueueForUploadJob, base_folder, report_file, organization.id, disconnected)
      assert_equal 'success', task.result, "Task should succeed when #{scenario[:description]}"
    end
  end
end
