-- AlterTable: allow upload-only edit sources; existing rows keep sourceDownloadJobId set.
ALTER TABLE "EditJob" ALTER COLUMN "sourceDownloadJobId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "EditJob" ADD COLUMN "sourceUploadId" TEXT;

-- CreateIndex
CREATE INDEX "EditJob_deviceId_sourceUploadId_idx" ON "EditJob"("deviceId", "sourceUploadId");

-- AddForeignKey
ALTER TABLE "EditJob" ADD CONSTRAINT "EditJob_sourceUploadId_fkey" FOREIGN KEY ("sourceUploadId") REFERENCES "UploadedMedia"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
