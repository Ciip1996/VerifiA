-- AlterTable
ALTER TABLE "tokens" ADD COLUMN     "liveness_match_score" INTEGER;

-- AlterTable
ALTER TABLE "user_profiles" ADD COLUMN     "enrollment_ref_id" TEXT;
