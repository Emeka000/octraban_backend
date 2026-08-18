export default {
  testEnvironment: "node",
  transform: {},
  testTimeout: 30000,
  coverageThreshold: {
    global: {
      lines: 88,
      branches: 70,
      functions: 88,
      statements: 88,
    },
    // Prioritise the decoder modules as specified in issue #21
    "./src/decoder.js": {
      lines: 80,
      branches: 60,
      functions: 80,
      statements: 80,
    },
    "./src/scval.js": {
      lines: 88,
      branches: 70,
      functions: 88,
      statements: 88,
    },
  },
};
