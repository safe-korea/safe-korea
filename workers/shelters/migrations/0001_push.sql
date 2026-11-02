-- Separate from personal family/GPS data: only opt-in delivery registrations.
CREATE TABLE IF NOT EXISTS push_subscriptions (
 id TEXT PRIMARY KEY, secret_hash TEXT NOT NULL, endpoint TEXT NOT NULL UNIQUE,
 p256dh TEXT NOT NULL, auth TEXT NOT NULL, region TEXT NOT NULL,
 created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, last_test_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS push_subscriptions_expiry ON push_subscriptions(expires_at);
CREATE TABLE IF NOT EXISTS push_deliveries (
 id TEXT PRIMARY KEY, subscription_id TEXT NOT NULL, notice_id TEXT NOT NULL,
 type TEXT NOT NULL, payload TEXT NOT NULL, expires_at INTEGER NOT NULL,
 receipt_hash TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending',
 received_at INTEGER, opened_at INTEGER,
 UNIQUE(subscription_id, notice_id)
);
CREATE INDEX IF NOT EXISTS push_delivery_expiry ON push_deliveries(expires_at);
CREATE TABLE IF NOT EXISTS alert_runtime (
 name TEXT PRIMARY KEY, value TEXT NOT NULL
);
