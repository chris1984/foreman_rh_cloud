import React from 'react';
import { Provider } from 'react-redux';
import configureMockStore from 'redux-mock-store';
import thunk from 'redux-thunk';
import { screen, render } from '@testing-library/react';
import { noop } from 'foremanReact/common/helpers';
import TabHeader from '../TabHeader';

const middlewares = [thunk];
const mockStore = configureMockStore(middlewares);

describe('TabHeader', () => {
  test('when subscription connection is enabled', () => {
    const renderOptions = {
      API: {
        INVENTORY_SETTINGS: {
          response: { subscriptionConnectionEnabled: true },
        },
      },
    };
    const store = mockStore(renderOptions);

    render(
      <Provider store={store}>
        <TabHeader exitCode="exit 0" onRestart={noop} toggleFullScreen={noop} />
      </Provider>
    );
    expect(screen.queryAllByText('Generate and upload report')).toHaveLength(1);
    expect(screen.queryAllByText('Full Screen')).toHaveLength(1);
  });

  test('when subscription connection is not enabled', () => {
    const renderOptions = {
      API: {
        INVENTORY_SETTINGS: {
          response: { subscriptionConnectionEnabled: false },
        },
      },
    };
    const store = mockStore(renderOptions);

    render(
      <Provider store={store}>
        <TabHeader exitCode="exit 0" onRestart={noop} toggleFullScreen={noop} />
      </Provider>
    );

    expect(screen.queryAllByText('Generate report')).toHaveLength(1);
    expect(screen.queryAllByText('Full Screen')).toHaveLength(1);
  });
});
