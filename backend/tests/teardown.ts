import { stopTestReplicaSet } from './fixtures/replicaSet';

export default async function teardown(): Promise<void> {
  // Stop isolated test replica set
  await stopTestReplicaSet();
}
