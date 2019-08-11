module ForemanYupana
  class ReportsController < ::ApplicationController
    def last
      label = ForemanYupana::Async::GenerateReportJob.output_label(params[:portal_user])
      output = ForemanYupana::Async::ProgressOutput.get(label)&.full_output

      render json: {
        output: output
      }, status: :ok
    end

    def generate
      portal_user = params[:portal_user]

      generated_file_name = File.join(ForemanYupana.base_folder, "#{portal_user}.tar.gz")
      ForemanYupana::Async::GenerateReportJob.perform_async(generated_file_name, portal_user)

      render json: {
        action_status: 'success'
      }, status: :ok
    end
  end
end