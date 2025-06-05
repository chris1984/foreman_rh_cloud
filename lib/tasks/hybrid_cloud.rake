require 'io/console'

namespace :rh_cloud do
  desc 'Register Satellite Organization with Hybrid Cloud API.'
  # This task registers the Satellite Organization with the Hybrid Cloud API.
  # It requires the user to input their organization ID, Insights URL, and token.
  # The task will then send a POST request to the Hybrid Cloud API to register the organization.
  # The response will be logged, and any errors will be caught and logged as well.
  # The task will exit with an error message if the organization does not have a manifest imported or if the token is not entered.
  # The task will also log a warning if the custom URL is not set and the default one is used.
  task hybridcloud_register: [:environment] do
    include ::ForemanRhCloud::CertAuth
    include ::InsightsCloud::CandlepinCache

    # Helper method to get a logger instance
    def logger
      @logger ||= Logger.new(STDOUT)
    end

    # Helper method to get the registrations URL, with a warning for default usage
    def registrations_url(custom_url = nil)
      if custom_url.blank?
        logger.warn("Custom url is not set, using the default one: #{ForemanRhCloud.base_url}")
        ForemanRhCloud.base_url + '/api/identity/certificate/registrations'
      else
        logger.warn("Custom Insights URL is set to: #{custom_url}")
        custom_url
      end
    end

    # --- Input Collection ---
    puts "\033[32mPaste in your organization ID, this can be retrieved with the command: hammer organization list\033[0m"
    loop do
      input = STDIN.gets.chomp
      if input.match?(/^\d+$/) # Checks if input consists only of digits
        @user_org_id = input.to_i
        break
      else
        puts "\033[31mInvalid input. Please enter a numeric organization ID.\033[0m"
      end
    end

    puts "\n" + "-" * 50 + "\n\n"
    puts "\033[32mPaste in your Custom Insights URL. If nothing is entered, the default will be used.\033[0m"
    insights_user_input = STDIN.gets.chomp

    # --- Data Preparation ---

    organization = Organization.find_by(id: @user_org_id)

    if organization.nil?
      logger.error("Organization with ID '#{@user_org_id}' not found.")
      exit(1)
    end

    uid = cp_owner_id(organization)
    if uid.nil?
      logger.error('Organization provided does not have a manifest imported.')
      exit(1)
    end

    hostname = ForemanRhCloud.foreman_host_name
    insights_url = registrations_url(insights_user_input) # Determine the insights URL

    puts "\n" + "-" * 50 + "\n\n"
    puts "\033[32mPaste in your Hybrid Cloud API token, output will be hidden.\033[0m"
    puts "\033[32mThis token can be retrieved from the Hybrid Cloud console.\033[0m"
    token = STDIN.noecho(&:gets).chomp

    if token.empty?
      logger.error('Token was not entered.')
      exit(1)
    end

    # --- API Request Configuration ---

    # Define headers as a local variable or a method that takes token
    headers = {
      Authorization: "Bearer #{token}",
    }

    # Define payload as a local variable or a method that takes required data
    payload = {
      "uid": uid,
      "display_name": "#{hostname}+#{organization.label}",
    }

    # --- Execute Request ---

    begin
      response = execute_cloud_request(
        organization: organization,
        method: :post,
        url: insights_url,
        headers: headers,
        payload: payload.to_json
      )
      logger.debug(response)
    # Add a more specific rescue for 401 Unauthorized errors
    rescue RestClient::Unauthorized => _ex
      logger.error("Registration failed: Your token is invalid or unauthorized. Please check your token and try again.")
      # Optionally, you can still log the full debug info if helpful for advanced troubleshooting
      # logger.debug(ex.backtrace.join("\n"))
      exit(1)
    rescue RestClient::ExceptionWithResponse => ex
      # This catches any RestClient exception that has a response (like 400, 403, 404, 500, etc.)
      status_code = begin
        ex.response.code
      rescue StandardError
        "unknown"
      end
      logger.error("Registration failed with HTTP status #{status_code}: #{ex.message}")
      logger.debug("Response body (if available): #{ex.response.body}")
      # logger.debug(ex.backtrace.join("\n"))
      exit(1)
    rescue StandardError => ex
      # This is the catch-all for any other unexpected errors
      logger.error("An unexpected error occurred during registration: #{ex.message}")
      # logger.debug(ex.backtrace.join("\n")) # Log backtrace for more info
      exit(1)
    end

    logger.info("Satellite Organization '#{organization.label}' (ID: #{@user_org_id}) successfully registered.")
  end
end
