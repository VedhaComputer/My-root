import { Server } from 'http';
import * as dbModule from '../../../src/config/database';
import {
  shutdown,
  registerSignalHandlers,
  _setServerInstanceForTesting,
  _resetShutdownPromiseForTesting,
  _resetSignalHandlersForTesting,
} from '../../../src/server';

describe('Server Graceful Shutdown (Unit Tests)', () => {
  let disconnectSpy: jest.SpyInstance;
  let mockServer: Partial<Server>;
  let consoleLogSpy: jest.SpyInstance;
  let consoleErrorSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    _resetShutdownPromiseForTesting();
    _resetSignalHandlersForTesting();
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    disconnectSpy = jest.spyOn(dbModule, 'disconnectDatabase').mockResolvedValue();
    mockServer = {
      listening: true,
      close: jest.fn((cb?: (err?: Error) => void) => {
        if (cb) cb();
        return mockServer as Server;
      }),
      closeIdleConnections: jest.fn(),
    };
    _setServerInstanceForTesting(mockServer as Server);
  });

  afterEach(() => {
    _setServerInstanceForTesting(null);
    _resetShutdownPromiseForTesting();
    _resetSignalHandlersForTesting();
    consoleLogSpy.mockRestore();
    consoleErrorSpy.mockRestore();
  });

  it('closes HTTP server first, then disconnects the database on graceful shutdown', async () => {
    const callOrder: string[] = [];

    mockServer.close = jest.fn((cb?: (err?: Error) => void) => {
      callOrder.push('server.close');
      if (cb) cb();
      return mockServer as Server;
    });

    disconnectSpy.mockImplementation(async () => {
      callOrder.push('disconnectDatabase');
    });

    await shutdown('SIGINT');

    expect(mockServer.closeIdleConnections).toHaveBeenCalled();
    expect(mockServer.close).toHaveBeenCalledTimes(1);
    expect(disconnectSpy).toHaveBeenCalledTimes(1);
    expect(callOrder).toEqual(['server.close', 'disconnectDatabase']);
  });

  it('is idempotent: concurrent shutdown invocations trigger cleanup only once and share promise', async () => {
    const firstCall = shutdown('SIGINT');
    const secondCall = shutdown('SIGTERM');

    await Promise.all([firstCall, secondCall]);

    expect(mockServer.close).toHaveBeenCalledTimes(1);
    expect(disconnectSpy).toHaveBeenCalledTimes(1);
  });

  it('handles server shutdown when HTTP server is null or not listening', async () => {
    _setServerInstanceForTesting(null);

    await shutdown();

    expect(disconnectSpy).toHaveBeenCalledTimes(1);
  });

  it('still performs database disconnect even if HTTP server close fails', async () => {
    mockServer.close = jest.fn((cb?: (err?: Error) => void) => {
      if (cb) cb(new Error('HTTP close failed'));
      return mockServer as Server;
    });

    await expect(shutdown('SIGTERM')).rejects.toThrow('Shutdown failed: HTTP close failed');

    // Database disconnect MUST have been called despite HTTP close error
    expect(disconnectSpy).toHaveBeenCalledTimes(1);
  });

  it('propagates error and fails if disconnectDatabase fails', async () => {
    disconnectSpy.mockRejectedValue(new Error('Database disconnect timeout'));

    await expect(shutdown('SIGINT')).rejects.toThrow('Shutdown failed: Database disconnect timeout');
  });

  it('captures both errors if both HTTP close and database disconnect fail', async () => {
    mockServer.close = jest.fn((cb?: (err?: Error) => void) => {
      if (cb) cb(new Error('Socket error'));
      return mockServer as Server;
    });
    disconnectSpy.mockRejectedValue(new Error('DB disconnect failed'));

    await expect(shutdown('SIGTERM')).rejects.toThrow(
      'Shutdown failed: Socket error; DB disconnect failed'
    );
    expect(disconnectSpy).toHaveBeenCalledTimes(1);
  });

  it('registerSignalHandlers is idempotent and does not attach duplicate process listeners', () => {
    const processOnceSpy = jest.spyOn(process, 'once');

    registerSignalHandlers();
    registerSignalHandlers();

    // Should register SIGINT and SIGTERM only once across both calls
    const sigintRegistrations = processOnceSpy.mock.calls.filter(([sig]) => sig === 'SIGINT');
    const sigtermRegistrations = processOnceSpy.mock.calls.filter(([sig]) => sig === 'SIGTERM');

    expect(sigintRegistrations).toHaveLength(1);
    expect(sigtermRegistrations).toHaveLength(1);

    processOnceSpy.mockRestore();
  });
});
