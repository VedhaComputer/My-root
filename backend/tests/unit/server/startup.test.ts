import { Server } from 'http';
import * as keysModule from '../../../src/config/keys';
import * as dbModule from '../../../src/config/database';
import * as redisModule from '../../../src/config/redis';
import * as appModule from '../../../src/app';
import { placeGatewayService } from '../../../src/modules/places/gateway';
import {
  startServer,
  _setServerInstanceForTesting,
  _resetShutdownPromiseForTesting,
  _resetSignalHandlersForTesting,
} from '../../../src/server';

describe('Server Startup Connectivity Check (Unit Tests)', () => {
  let mockServer: Partial<Server>;
  let checkHealthSpy: jest.SpyInstance;
  let isProxyEnabledSpy: jest.SpyInstance;
  let consoleLogSpy: jest.SpyInstance;
  let consoleErrorSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    _resetShutdownPromiseForTesting();
    _resetSignalHandlersForTesting();

    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    jest.spyOn(keysModule, 'validateJwtKeysOnStartup').mockImplementation(() => {});
    jest.spyOn(dbModule, 'connectDatabase').mockResolvedValue();
    jest.spyOn(redisModule, 'connectRedis').mockResolvedValue(null as any);

    mockServer = {
      listening: true,
      close: jest.fn((cb?: (err?: Error) => void) => {
        if (cb) cb();
        return mockServer as Server;
      }),
      once: jest.fn(),
    };

    jest.spyOn(appModule, 'createApp').mockReturnValue({
      listen: jest.fn((_port: any, cb?: () => void) => {
        if (cb) {
          process.nextTick(cb);
        }
        return mockServer as Server;
      }),
    } as any);

    checkHealthSpy = jest.spyOn(placeGatewayService, 'checkUpstreamHealth').mockResolvedValue({
      connected: true,
      status: 200,
      service: 'india-place-api',
      attempts: 1,
    });
    isProxyEnabledSpy = jest.spyOn(placeGatewayService, 'isProxyEnabled').mockReturnValue(true);
  });

  afterEach(() => {
    _setServerInstanceForTesting(null);
    _resetShutdownPromiseForTesting();
    _resetSignalHandlersForTesting();
    jest.restoreAllMocks();
  });

  it('automatically invokes upstream connectivity check when proxy is enabled on startup', async () => {
    isProxyEnabledSpy.mockReturnValue(true);

    const server = await startServer();

    expect(checkHealthSpy).toHaveBeenCalledTimes(1);
    expect(server).toBe(mockServer);
  });

  it('skips connectivity check when proxy is disabled on startup', async () => {
    isProxyEnabledSpy.mockReturnValue(false);

    const server = await startServer();

    expect(checkHealthSpy).not.toHaveBeenCalled();
    expect(server).toBe(mockServer);
  });

  it('preserves successful startup even when upstream connectivity check fails', async () => {
    isProxyEnabledSpy.mockReturnValue(true);
    checkHealthSpy.mockResolvedValueOnce({
      connected: false,
      status: 503,
      error: 'Upstream returned HTTP status 503',
      attempts: 3,
    });

    const server = await startServer();

    expect(checkHealthSpy).toHaveBeenCalledTimes(1);
    // Server must still start successfully and not crash
    expect(server).toBe(mockServer);
    expect(consoleErrorSpy).not.toHaveBeenCalledWith(
      expect.stringContaining('Failed to start server')
    );
  });
});
