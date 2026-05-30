import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          bindings: { LICENSE_ISS: "api.devtray.app.test" },
          kvNamespaces: ["LICENSES", "LICENSES_TEST", "EVENTS"],
        },
      },
    },
  },
});
