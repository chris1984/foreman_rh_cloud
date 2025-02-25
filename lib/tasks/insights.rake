namespace :rh_cloud_insights do
  desc "Synchronize Insights hosts hits"
  task sync: [:environment, 'dynflow:client'] do
    ForemanTasks.sync_task(InsightsCloud::Async::InsightsFullSync, Organization.unscoped.all)
    puts "Synchronized Insights hosts hits data"
  end

  desc "Remove insights client report statuses by searching on host criteria"
  task clean_statuses: [:environment] do
    hosts_search = ENV['SEARCH']

    if hosts_search.empty?
      puts 'Must specify SEARCH= criteria for hosts search'
      next
    end

    cleaner = ForemanRhCloud::InsightsStatusCleaner.new
    User.as_anonymous_admin do
      deleted_count = cleaner.clean(hosts_search)
      puts "Deleted #{deleted_count} insights statuses"
    end
  end

  desc "Re-announce all organizations into Sources on RH cloud."
  task announce_to_sources: [:environment] do
    logger = Logging::Logger.new(STDOUT)
    if ForemanRhCloud.with_local_advisor_engine?
      logger.warn('Task announce_to_sources is not available when using local advisor engine')
    else
      Organization.unscoped.each do |org|
        presence = ForemanRhCloud::CloudPresence.new(org, logger)
        presence.announce_to_sources
      rescue StandardError => ex
        logger.warn(ex)
      end
      logger.info('Reannounced all organizations')
    end
  end
end
