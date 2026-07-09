-- CreateTable
CREATE TABLE "challenges" (
    "id" TEXT NOT NULL,
    "nonce" TEXT NOT NULL,
    "verifier_id" TEXT NOT NULL,
    "exp_time" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "challenges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tokens" (
    "id" TEXT NOT NULL,
    "jti" TEXT NOT NULL,
    "nonce" TEXT NOT NULL,
    "aud" TEXT NOT NULL,
    "exp" TIMESTAMP(3) NOT NULL,
    "iat" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "jwt_raw" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_attest_keys" (
    "id" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "public_key_pem" TEXT NOT NULL,
    "attestation_data" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "app_attest_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "token_jti" TEXT,
    "device_id" TEXT,
    "result" TEXT NOT NULL,
    "metadata" JSONB,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "challenges_nonce_key" ON "challenges"("nonce");

-- CreateIndex
CREATE INDEX "challenges_verifier_id_idx" ON "challenges"("verifier_id");

-- CreateIndex
CREATE INDEX "challenges_status_idx" ON "challenges"("status");

-- CreateIndex
CREATE UNIQUE INDEX "tokens_jti_key" ON "tokens"("jti");

-- CreateIndex
CREATE UNIQUE INDEX "tokens_nonce_key" ON "tokens"("nonce");

-- CreateIndex
CREATE INDEX "tokens_status_idx" ON "tokens"("status");

-- CreateIndex
CREATE INDEX "tokens_aud_idx" ON "tokens"("aud");

-- CreateIndex
CREATE UNIQUE INDEX "app_attest_keys_device_id_key" ON "app_attest_keys"("device_id");

-- CreateIndex
CREATE INDEX "audit_logs_action_idx" ON "audit_logs"("action");

-- CreateIndex
CREATE INDEX "audit_logs_timestamp_idx" ON "audit_logs"("timestamp");
