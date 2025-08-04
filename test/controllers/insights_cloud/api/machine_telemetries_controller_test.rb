require 'test_plugin_helper'
require 'rest-client'

module InsightsCloud::Api
  class MachineTelemetriesControllerTest < ActionController::TestCase
    include KatelloCVEHelper

    setup do
      FactoryBot.create(:common_parameter, name: InsightsCloud.enable_client_param, key_type: 'boolean', value: true)
    end

    context '#forward_request' do
      include MockCerts

      setup do
        @body = 'Cloud response body'
        @http_req = RestClient::Request.new(:method => 'GET', :url => 'http://test.theforeman.org')

        org = FactoryBot.create(:organization)
        host = FactoryBot.create(:host, :with_subscription, :organization => org)
        User.current = ::Katello::CpConsumerUser.new(:uuid => host.subscription_facet.uuid, :login => host.subscription_facet.uuid)
        InsightsCloud::Api::MachineTelemetriesController.any_instance.stubs(:upstream_owner).returns({ 'uuid' => 'abcdefg' })

        setup_certs_expectation do
          InsightsCloud::Api::MachineTelemetriesController.any_instance.stubs(:candlepin_id_cert)
        end
      end

      test "should respond with response from cloud" do
        net_http_resp = Net::HTTPResponse.new(1.0, 200, "OK")
        net_http_resp.add_field 'Set-Cookie', 'Monster'
        res = RestClient::Response.create(@body, net_http_resp, @http_req)
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:forward_request).returns(res)

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal @body, @response.body
      end

      test "should handle timeout from cloud" do
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.
          stubs(:forward_request).
          raises(RestClient::Exceptions::OpenTimeout.new("Timed out connecting to server"))

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        request_response = JSON.parse(@response.body)
        # I can't get @response.status to take a nil value so I'm not asserting for that

        assert_equal 'Timed out connecting to server', request_response['error']
      end

      test "should respond with the same content type" do
        net_http_resp = Net::HTTPResponse.new(1.0, 200, "OK")
        net_http_resp.add_field 'Set-Cookie', 'Monster'
        res = RestClient::Response.create(@body, net_http_resp, @http_req)
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.expects(:execute_cloud_request).with do |opts|
          opts[:headers][:content_type] == 'application/json'
        end.returns(res)
        InsightsCloud::Api::MachineTelemetriesController.any_instance.expects(:cp_owner_id).returns('123')

        post :forward_request, as: :json, params: { "path" => "static/v1/test", "machine_telemetry" => { "foo" => "bar" } }
        assert_equal @body, @response.body
      end

      test "should add headers to response from cloud" do
        x_resource_count = '101'
        x_rh_insights_request_id = '202'
        net_http_resp = Net::HTTPResponse.new(1.0, 200, "OK")
        net_http_resp['x_resource_count'] = x_resource_count
        net_http_resp['x_rh_insights_request_id'] = x_rh_insights_request_id
        res = RestClient::Response.create(@body, net_http_resp, @http_req)
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:forward_request).returns(res)

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal x_resource_count, @response.headers['x-resource-count']
        assert_equal x_rh_insights_request_id, @response.headers['x_rh_insights_request_id']
      end

      test "should set etag header to response from cloud" do
        etag = '12345'
        req = RestClient::Request.new(:method => 'GET', :url => 'http://test.theforeman.org', :headers => { "If-None-Match": etag })
        net_http_resp = Net::HTTPResponse.new(1.0, 200, "OK")
        net_http_resp[Rack::ETAG] = etag
        res = RestClient::Response.create(@body, net_http_resp, req)
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:forward_request).returns(res)

        get :forward_request, params: { "path" => "static/v1/release/insights-core.egg" }
        assert_equal etag, @response.headers[Rack::ETAG]
      end

      test "should set content type header to response from cloud" do
        req = RestClient::Request.new(:method => 'GET', :url => 'http://test.theforeman.org')
        net_http_resp = Net::HTTPResponse.new(1.0, 200, "OK")
        net_http_resp[:content_type] = 'application/zip'
        res = RestClient::Response.create(@body, net_http_resp, req)
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:forward_request).returns(res)

        get :forward_request, params: { "path" => "static/v1/release/insights-core.egg" }
        assert_equal net_http_resp[:content_type], @response.headers['Content-Type']
      end

      test "should handle StandardError" do
        error_message = "Connection refused"
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:execute_cloud_request).raises(Errno::ECONNREFUSED.new)

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal 502, @response.status
        body = JSON.parse(@response.body)
        assert_equal error_message, body['error']
      end

      test "should handle 304 cloud" do
        net_http_resp = Net::HTTPResponse.new(1.0, 304, "Not Modified")
        res = RestClient::Response.create(@body, net_http_resp, @http_req)

        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:execute_cloud_request).raises(RestClient::NotModified.new(res))

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal 304, @response.status
        assert_equal 'Cloud request not modified', JSON.parse(@response.body)['message']
      end

      test "should handle RestClient::Exceptions::Timeout" do
        timeout_message = "execution expired"
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:execute_cloud_request).raises(RestClient::Exceptions::Timeout.new(timeout_message))

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal 504, @response.status
        body = JSON.parse(@response.body)
        assert_equal timeout_message, body['message']
        assert_equal timeout_message, body['error']
      end

      test "should handle failed authentication to cloud" do
        net_http_resp = Net::HTTPResponse.new(1.0, 401, "Unauthorized")
        res = RestClient::Response.create(@body, net_http_resp, @http_req)

        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:execute_cloud_request).raises(RestClient::Unauthorized.new(res))

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal 401, @response.status
        assert_equal 'Authentication to the Insights Service failed.', JSON.parse(@response.body)['message']
      end

      test "should forward errors to the client" do
        net_http_resp = Net::HTTPResponse.new(1.0, 500, "TEST_RESPONSE")
        res = RestClient::Response.create(@body, net_http_resp, @http_req)
        ::ForemanRhCloud::CloudRequestForwarder.any_instance.stubs(:execute_cloud_request).raises(RestClient::InternalServerError.new(res))

        get :forward_request, params: { "path" => "platform/module-update-router/v1/channel" }
        assert_equal 500, @response.status
        assert_equal 'Cloud request failed', JSON.parse(@response.body)['message']
        assert_match /#{@body}/, JSON.parse(@response.body)['response']
      end
    end

    context '#branch_info' do
      setup do
        UpstreamOnlySettingsTestHelper.set_if_available('allow_multiple_content_views')
        User.current = User.find_by(login: 'secret_admin')
        env = FactoryBot.create(:katello_k_t_environment)
        env2 = FactoryBot.create(:katello_k_t_environment, organization: env.organization)

        @host = FactoryBot.create(
          :host,
          :with_subscription,
          :with_content,
          :with_hostgroup,
          :with_parameter,
          content_facet: FactoryBot.build(
            :content_facet,
            content_view_environments: [make_cve(lifecycle_environment: env), make_cve(lifecycle_environment: env2)]
          ),
          organization: env.organization
        )

        @host.subscription_facet.pools << FactoryBot.create(:katello_pool, account_number: '5678', cp_id: 1)

        uuid = @host.subscription_facet.uuid

        @user = ::Katello::CpConsumerUser.new({ :uuid => uuid, :login => uuid })

        @controller.stub(:set_client_user, @user) do
          User.current = @user
        end

        @controller.stubs(:cp_owner_id).returns('test-branch-id')
      end

      test 'should get branch info' do
        get :branch_info

        res = JSON.parse(@response.body)

        assert_not_equal 0, res['labels'].find { |l| l['key'] == 'hostgroup' }.count

        assert_response :success
      end

      test 'should handle missing organization' do
        Host::Managed.any_instance.stubs(:organization).returns(nil)
        get :branch_info

        res = JSON.parse(@response.body)
        assert_equal "Organization not found or invalid", res['message']
        assert_response 400
      end

      test 'should handle missing branch id' do
        @controller.stubs(:cp_owner_id).returns(nil)
        get :branch_info

        res = JSON.parse(@response.body)
        assert_equal "Branch ID not found for organization #{@host.organization.title}", res['message']
        assert_response 400
      end
    end
  end
end
