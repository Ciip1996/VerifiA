-- AlterTable
ALTER TABLE "challenges" ADD COLUMN     "account_id" TEXT,
ADD COLUMN     "rejection_reason" TEXT,
ADD COLUMN     "target_email" TEXT;

-- CreateTable
CREATE TABLE "accounts" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "accounts_email_key" ON "accounts"("email");

-- CreateIndex
CREATE UNIQUE INDEX "accounts_device_id_key" ON "accounts"("device_id");

-- CreateIndex
CREATE INDEX "challenges_account_id_idx" ON "challenges"("account_id");

-- CreateIndex
CREATE INDEX "challenges_target_email_idx" ON "challenges"("target_email");
