import React from 'react';
import PropTypes from 'prop-types';
import { noop } from 'foremanReact/common/helpers';
import TabContainer from '../TabContainer';
import TabHeader from '../TabHeader';
import TabBody from '../TabBody';
import './reportGenerate.scss';

const ReportGenerate = ({
  exitCode,
  logs,
  completed,
  error,
  restartProcess,
  downloadReports,
  downloadButtonDisabled,
  toggleFullScreen,
  scheduled,
}) => (
  <TabContainer className="report-generate">
    <TabHeader
      exitCode={exitCode}
      onRestart={restartProcess}
      onDownload={downloadReports}
      downloadButtonDisabled={downloadButtonDisabled}
      toggleFullScreen={toggleFullScreen}
    />
    <TabBody
      exitCode={exitCode}
      logs={logs}
      completed={completed}
      error={error}
      scheduled={scheduled}
    />
  </TabContainer>
);

ReportGenerate.propTypes = {
  exitCode: PropTypes.string,
  logs: PropTypes.oneOfType([
    PropTypes.arrayOf(PropTypes.string),
    PropTypes.string,
  ]),
  completed: PropTypes.number,
  error: PropTypes.string,
  restartProcess: PropTypes.func,
  downloadReports: PropTypes.func,
  downloadButtonDisabled: PropTypes.func,
  toggleFullScreen: PropTypes.func,
  scheduled: PropTypes.string,
};

ReportGenerate.defaultProps = {
  exitCode: '',
  logs: null,
  completed: 0,
  error: null,
  restartProcess: noop,
  downloadReports: noop,
  downloadButtonDisabled: noop,
  toggleFullScreen: noop,
  scheduled: null,
};

export default ReportGenerate;
