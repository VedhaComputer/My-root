import crypto from 'crypto';

export interface RateLimitRecord {
  hits: number;
  expiresAt: number;
}

/**
 * Deterministic in-memory Redis client mock for distributed rate limiting tests.
 *
 * Simulates:
 * - Atomic Lua scripts (SCRIPT LOAD, EVALSHA) used by rate-limit-redis.
 * - Key TTLs and bounded expiration.
 * - Multi-instance shared state: multiple mock clients can share the same underlying storage.
 * - Configurable connection drops / network failures without live external Redis instances.
 */
export class InMemoryRedisMock {
  public data: Map<string, RateLimitRecord>;
  public scripts: Map<string, string>;
  public status: 'ready' | 'connecting' | 'disconnected';
  private timeOffsetMs = 0;

  constructor(sharedData?: Map<string, RateLimitRecord>, sharedScripts?: Map<string, string>) {
    this.data = sharedData ?? new Map<string, RateLimitRecord>();
    this.scripts = sharedScripts ?? new Map<string, string>();
    this.status = 'ready';
  }

  public on(_event: string, _handler: (...args: any[]) => void): this {
    return this;
  }

  public now(): number {
    return Date.now() + this.timeOffsetMs;
  }

  public advanceTime(ms: number): void {
    this.timeOffsetMs += ms;
  }

  public simulateDisconnect(): void {
    this.status = 'disconnected';
  }

  public simulateReconnect(): void {
    this.status = 'ready';
  }

  public async ping(): Promise<string> {
    if (this.status !== 'ready') {
      throw new Error('Redis connection refused: ECONNREFUSED 127.0.0.1:6379');
    }
    return 'PONG';
  }

  public async connect(): Promise<void> {
    if (this.status === 'disconnected') {
      throw new Error('Redis connection failed');
    }
    this.status = 'ready';
  }

  public async quit(): Promise<void> {
    this.status = 'disconnected';
  }

  public disconnect(): void {
    this.status = 'disconnected';
  }

  public async keys(pattern: string): Promise<string[]> {
    return this.call('keys', pattern);
  }

  public async del(...keys: string[]): Promise<number> {
    return this.call('del', ...keys);
  }

  /**
   * Creates a second client instance sharing the exact same in-memory data store.
   * Simulates a second backend node in a multi-instance cluster.
   */
  public createPeerInstance(): InMemoryRedisMock {
    const peer = new InMemoryRedisMock(this.data, this.scripts);
    return peer;
  }

  public async call(command: string, ...args: string[]): Promise<any> {
    if (this.status !== 'ready') {
      throw new Error('Redis connection is closed: ECONNREFUSED 127.0.0.1:6379');
    }

    const cmd = command.toLowerCase();

    if (cmd === 'ping') {
      return 'PONG';
    }

    if (cmd === 'script') {
      const sub = (args[0] || '').toLowerCase();
      if (sub === 'load') {
        const script = args[1] || '';
        const sha = crypto.createHash('sha1').update(script).digest('hex');
        this.scripts.set(sha, script);
        return sha;
      }
      throw new Error(`Unsupported SCRIPT subcommand: ${sub}`);
    }

    if (cmd === 'evalsha') {
      const sha = args[0];
      const key = args[2];
      const resetExpiry = args[3] === '1';
      const windowMs = parseInt(args[4] || '60000', 10);

      const currentTime = this.now();
      let record = this.data.get(key);

      // Clean up if expired
      if (record && record.expiresAt <= currentTime) {
        this.data.delete(key);
        record = undefined;
      }

      if (!record) {
        record = {
          hits: 1,
          expiresAt: currentTime + windowMs,
        };
        this.data.set(key, record);
      } else {
        record.hits += 1;
        if (resetExpiry) {
          record.expiresAt = currentTime + windowMs;
        }
      }

      const ttlRemaining = Math.max(0, record.expiresAt - currentTime);
      return [record.hits, ttlRemaining];
    }

    if (cmd === 'del') {
      let count = 0;
      for (const k of args) {
        if (this.data.delete(k)) {
          count++;
        }
      }
      return count;
    }

    if (cmd === 'set') {
      const key = args[0];
      const record: RateLimitRecord = {
        hits: 1,
        expiresAt: this.now() + 60000,
      };
      this.data.set(key, record);
      return 'OK';
    }

    if (cmd === 'keys') {
      const pattern = args[0] || '*';
      const regexStr = '^' + pattern.replace(/\*/g, '.*') + '$';
      const regex = new RegExp(regexStr);
      const currentTime = this.now();
      const matched: string[] = [];
      for (const [key, record] of this.data.entries()) {
        if (record.expiresAt > currentTime && regex.test(key)) {
          matched.push(key);
        }
      }
      return matched;
    }

    if (cmd === 'get') {
      const key = args[0];
      const record = this.data.get(key);
      const currentTime = this.now();
      if (!record || record.expiresAt <= currentTime) {
        this.data.delete(key);
        return null;
      }
      return String(record.hits);
    }

    if (cmd === 'flushdb' || cmd === 'flushall') {
      this.data.clear();
      return 'OK';
    }

    throw new Error(`InMemoryRedisMock: Unhandled Redis command "${cmd}"`);
  }
}
