-- AlterTable
ALTER TABLE "tokens" ADD COLUMN     "device_id" TEXT,
ADD COLUMN     "liveness_snapshot" TEXT;

-- CreateTable
CREATE TABLE "user_profiles" (
    "id" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "student_id" TEXT,
    "curp" TEXT,
    "date_of_birth" TEXT,
    "id_type" TEXT NOT NULL,
    "profile_photo" TEXT NOT NULL,
    "id_front_photo" TEXT NOT NULL,
    "id_back_photo" TEXT,
    "facetec_match_level" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_profiles_device_id_key" ON "user_profiles"("device_id");

-- CreateIndex
CREATE INDEX "tokens_device_id_idx" ON "tokens"("device_id");
