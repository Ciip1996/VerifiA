-- AlterTable
ALTER TABLE "user_profiles" DROP COLUMN "student_id";

-- CreateTable
CREATE TABLE "verification_receipts" (
    "id" TEXT NOT NULL,
    "jti" TEXT NOT NULL,
    "challenge_nonce" TEXT NOT NULL,
    "badge_jti" TEXT NOT NULL,
    "account_id" TEXT,
    "device_id" TEXT,
    "subject_name" TEXT,
    "issued_via" TEXT NOT NULL,
    "verified_at" TIMESTAMP(3) NOT NULL,
    "badge_valid_from" TIMESTAMP(3) NOT NULL,
    "badge_valid_until" TIMESTAMP(3) NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "receipt_jwt_raw" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "verification_receipts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "verification_receipts_jti_key" ON "verification_receipts"("jti");

-- CreateIndex
CREATE UNIQUE INDEX "verification_receipts_challenge_nonce_key" ON "verification_receipts"("challenge_nonce");

-- CreateIndex
CREATE INDEX "verification_receipts_account_id_idx" ON "verification_receipts"("account_id");

-- CreateIndex
CREATE INDEX "verification_receipts_badge_jti_idx" ON "verification_receipts"("badge_jti");
