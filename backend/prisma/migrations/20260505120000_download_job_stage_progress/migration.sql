-- AlterTable
ALTER TABLE "DownloadJob" ADD COLUMN "processingStage" TEXT;

-- AlterTable: allow NULL progress for unknown-percent UX
ALTER TABLE "DownloadJob" ALTER COLUMN "progress" DROP DEFAULT;
ALTER TABLE "DownloadJob" ALTER COLUMN "progress" DROP NOT NULL;
