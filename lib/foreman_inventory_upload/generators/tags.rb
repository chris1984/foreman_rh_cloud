module ForemanInventoryUpload
  module Generators
    class Tags
      def initialize(host)
        @host = host
      end

      def generate
        (
          locations +
          hostgroups +
          host_collections +
          organizations +
          content_data +
          satellite_server_data
        ).reject { |key, value| value.empty? }.map { |key, value| [key, truncated_value(value)] }
      end

      def generate_parameters
        return [] unless Setting[:include_parameter_tags]

        (@host.host_params || {})
          .select { |_name, value| value.present? || value.is_a?(FalseClass) }
          .map { |key, value| [key, truncated_value(value)] }
      end

      private

      def locations
        return [] unless @host.location
        @host.location.title.split('/').map { |item| ['location', item] }.push(['location', @host.location.title])
      end

      def hostgroups
        return [] unless @host.hostgroup
        @host.hostgroup.title.split('/').map { |item| ['hostgroup', item] }.push(['hostgroup', @host.hostgroup.title])
      end

      def host_collections
        (@host.host_collections || []).map { |item| ['host collection', item.name] }
      end

      def organizations
        [
          ['organization', @host.organization.name],
          ['organization_label', @host.organization.label],
        ]
      end

      def content_data
        (@host.lifecycle_environments.uniq || []).map { |item| ['lifecycle_environment', item.name] } +
        (@host.activation_keys || []).map { |item| ['activation_key', item.name] } +
        (@host.content_views || []).map { |item| ['content_view', item.name] }
      end

      def satellite_server_data
        [
          ['satellite_instance_id', Foreman.instance_id],
          ['organization_id', @host.organization_id.to_s],
        ]
      end

      def truncated_value(value)
        return 'Original value exceeds 250 characters' if value.to_s.length > 250

        value
      end
    end
  end
end
