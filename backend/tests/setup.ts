import { startTestReplicaSet } from './fixtures/replicaSet';

export default async function setup(): Promise<void> {
  process.env.NODE_ENV = 'test';
  process.env.MONGODB_URI = 'mongodb://localhost:27017/myroot_test';
  process.env.JWT_ACCESS_SECRET = 'test_access_secret_minimum_32_characters_long';
  process.env.JWT_REFRESH_SECRET = 'test_refresh_secret_minimum_32_characters_long';
  process.env.PORT = '3002';
  process.env.CORS_ORIGINS = 'http://localhost:3000';

  // Automatically start isolated replica set on port 27018 if mongod binary is present
  await startTestReplicaSet();
}
