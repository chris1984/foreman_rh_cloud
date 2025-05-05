import React from 'react';
import { useSelector } from 'react-redux';
import PropTypes from 'prop-types';
import { Grid, Button, Icon } from 'patternfly-react';
import { noop } from 'foremanReact/common/helpers';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { selectSubscriptionConnectionEnabled } from '../InventorySettings/InventorySettingsSelectors';
import { isExitCodeLoading } from '../../ForemanInventoryHelpers';
import './tabHeader.scss';

const TabHeader = ({ exitCode, onRestart, onDownload, toggleFullScreen }) => {
  const subscriptionConnectionEnabled = useSelector(
    selectSubscriptionConnectionEnabled
  );
  const buttonGenerateLabel = subscriptionConnectionEnabled
    ? __('Generate and upload report')
    : __('Generate report');

  return (
    <Grid.Row className="tab-header">
      <Grid.Col sm={6}>
        <p>{sprintf(__('Exit Code: %s'), exitCode)}</p>
      </Grid.Col>
      <Grid.Col sm={6}>
        <div className="tab-action-buttons">
          {onRestart ? (
            <Button
              bsStyle="primary"
              onClick={onRestart}
              disabled={isExitCodeLoading(exitCode)}
            >
              {buttonGenerateLabel}
            </Button>
          ) : null}
          {onDownload ? (
            <Button onClick={onDownload}>
              {__('Download Report')} <Icon name="download" />
            </Button>
          ) : null}
          <Button onClick={toggleFullScreen}>
            {__('Full Screen')}
            <Icon name="arrows-alt" />
          </Button>
        </div>
      </Grid.Col>
    </Grid.Row>
  );
};

TabHeader.propTypes = {
  onRestart: PropTypes.func,
  onDownload: PropTypes.func,
  exitCode: PropTypes.string,
  toggleFullScreen: PropTypes.func,
};

TabHeader.defaultProps = {
  onRestart: null,
  exitCode: '',
  onDownload: null,
  toggleFullScreen: noop,
};

export default TabHeader;
