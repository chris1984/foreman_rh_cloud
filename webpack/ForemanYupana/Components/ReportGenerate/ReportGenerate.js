import React from 'react';
import PropTypes from 'prop-types';
import { noop } from 'patternfly-react';
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
}) => (
  <TabContainer className="report-generate">
    <TabHeader exitCode={exitCode} onRestart={restartProcess} />
    <TabBody
      exitCode={exitCode}
      logs={logs}
      completed={completed}
      error={error}
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
};

ReportGenerate.defaultProps = {
  exitCode: '',
  logs: null,
  completed: 0,
  error: null,
  restartProcess: noop,
};

export default ReportGenerate;