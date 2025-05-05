import React from 'react';
import PropTypes from 'prop-types';
import { Switch } from '@patternfly/react-core';
import { HelpLabel } from './HelpLabel';
import './SwitcherPF4.scss';

const SwitcherPF4 = ({
  id,
  label,
  tooltip,
  isChecked,
  onChange,
  isDisabled,
}) => (
  <Switch
    className="foreman-rh-cloud-switcher"
    id={`rh-cloud-switcher-${id}`}
    isChecked={isChecked}
    isDisabled={isDisabled}
    onChange={onChange}
    label={
      <div>
        {label}
        <HelpLabel text={tooltip} id={id} className="switcher-help-label" />
      </div>
    }
  />
);

SwitcherPF4.propTypes = {
  id: PropTypes.string.isRequired,
  label: PropTypes.string,
  tooltip: PropTypes.string,
  isChecked: PropTypes.bool,
  isDisabled: PropTypes.bool,
  onChange: PropTypes.func.isRequired,
};

SwitcherPF4.defaultProps = {
  label: null,
  tooltip: null,
  isChecked: true,
  isDisabled: false,
};

export default SwitcherPF4;
