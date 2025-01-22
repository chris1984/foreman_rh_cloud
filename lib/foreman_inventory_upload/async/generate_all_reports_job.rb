module ForemanInventoryUpload
  module Async
    class GenerateAllReportsJob < ::Actions::EntryAction
      include ::Actions::RecurringAction
      include ForemanInventoryUpload::Async::DelayedStart

      def plan
        unless Setting[:allow_auto_inventory_upload]
          logger.debug(
            'The scheduled process is disabled due to the "allow_auto_inventory_upload"
            setting being set to false.'
          )
          return
        end

        if ForemanRhCloud.with_local_advisor_engine?
          plan_self # so that 'run' runs
        else
          after_delay do
            organizations = Organization.unscoped.all

            organizations.map do |organization|
              total_hosts = ForemanInventoryUpload::Generators::Queries.for_org(organization.id, use_batches: false).count

              if total_hosts <= ForemanInventoryUpload.max_org_size
                disconnected = false
                plan_generate_report(ForemanInventoryUpload.generated_reports_folder, organization, disconnected)
              else
                logger.info("Skipping automatic uploads for organization #{organization.name}, too many hosts (#{total_hosts}/#{ForemanInventoryUpload.max_org_size})")
              end
            end.compact
          end
        end
      end

      def run
        output[:status] = _('The scheduled process is disabled because this Foreman is configured with the use_local_advisor_engine option.') if ForemanRhCloud.with_local_advisor_engine?
      end

      def rescue_strategy_for_self
        Dynflow::Action::Rescue::Fail
      end

      def plan_generate_report(folder, organization, disconnected)
        plan_action(ForemanInventoryUpload::Async::GenerateReportJob, folder, organization.id, disconnected)
      end

      def logger
        action_logger
      end
    end
  end
end
