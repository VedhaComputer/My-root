import { TEST_RSA_PRIVATE_KEY, TEST_RSA_PUBLIC_KEY } from './fixtures/testKeys';

// Configure in-memory test environment before test modules import application configuration
process.env.JWT_PRIVATE_KEY = TEST_RSA_PRIVATE_KEY;
process.env.JWT_PUBLIC_KEY = TEST_RSA_PUBLIC_KEY;
process.env.JWT_ISSUER = 'myroot-backend';
process.env.JWT_AUDIENCE = 'myroot-platform';

