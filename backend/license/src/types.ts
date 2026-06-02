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
  paddle_transaction_id?: string;
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
  // Paddle Billing v1 server API key used by /buy to create a transaction
  // and 302-redirect the buyer to the resulting checkout URL.
  PADDLE_API_KEY: string;
  // The Paddle price the /buy route mints a transaction for, e.g. "pri_01h…".
  PADDLE_PRICE_ID: string;
  // Optional API base URL override — defaults to https://api.paddle.com (prod).
  // Set to "https://sandbox-api.paddle.com" for sandbox testing.
  PADDLE_API_BASE_URL?: string;
  RESEND_API_KEY: string;
  ADMIN_TOKEN: string;
  LICENSE_ISS: string;
};
