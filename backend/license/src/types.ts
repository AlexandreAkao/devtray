export type Activation = {
  machine_hash: string;
  activated_at: number;
};

export type LicenseRecord = {
  user_email: string;
  created_at: number;
  activations: Activation[];
  revoked: boolean;
  test_mode: boolean;
  // Paddle is the active provider going forward.
  paddle_transaction_id?: string;
  // Read-only fallback for v0.11-era records minted under LemonSqueezy.
  // Removed in v1.0.1 once production KV has zero ls_order_id records.
  ls_order_id?: string;
};

export type EventRecord = {
  processed_at: number;
  outcome: "minted" | "revoked" | "skipped";
};

export type Env = {
  LICENSES: KVNamespace;
  LICENSES_TEST: KVNamespace;
  EVENTS: KVNamespace;
  LICENSE_PRIVATE_KEY: string;
  PADDLE_NOTIFICATION_SECRET: string;
  PADDLE_MAGIC_LINK_URL: string;
  RESEND_API_KEY: string;
  ADMIN_TOKEN: string;
  LICENSE_ISS: string;
};
