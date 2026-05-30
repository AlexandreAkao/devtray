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
  ls_order_id: string;
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
  LEMONSQUEEZY_WEBHOOK_SECRET: string;
  RESEND_API_KEY: string;
  ADMIN_TOKEN: string;
  LICENSE_ISS: string;
};
