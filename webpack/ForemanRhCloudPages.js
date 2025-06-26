import React from 'react';
import componentRegistry from 'foremanReact/components/componentRegistry';
import { registerRoutes as foremanRegisterRoutes } from 'foremanReact/routes/RoutingService';
import ForemanInventoryUpload from './ForemanInventoryUpload';
import InsightsVulnerability from './InsightsVulnerability/InsightsVulnerability';
import InsightsCloudSync from './InsightsCloudSync';
import InsightsHostDetailsTab from './InsightsHostDetailsTab';

const pages = [
  { name: 'ForemanInventoryUpload', type: ForemanInventoryUpload },
  { name: 'InsightsCloudSync', type: InsightsCloudSync },
  { name: 'InsightsHostDetailsTab', type: InsightsHostDetailsTab },
  { name: 'InsightsVulnerability', type: InsightsVulnerability },
];

export const registerPages = () => {
  pages.forEach(page => componentRegistry.register(page));
};

export const routes = [
  {
    path: '/foreman_rh_cloud/insights_cloud',
    exact: true,
    render: props => <InsightsCloudSync {...props} />,
  },
  {
    path: '/foreman_rh_cloud/inventory_upload',
    exact: true,
    render: props => <ForemanInventoryUpload {...props} />,
  },
  {
    path: '/foreman_rh_cloud/insights_vulnerability',
    exact: true,
    render: props => <InsightsVulnerability {...props} />,
  },
];

export const registerRoutes = () => {
  foremanRegisterRoutes('foreman_rh_cloud', routes);
};
