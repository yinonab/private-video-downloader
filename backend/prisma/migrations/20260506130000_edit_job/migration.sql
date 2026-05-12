-- CreateTable
CREATE TABLE "EditJob" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "sourceDownloadJobId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "stage" TEXT,
    "progressPercent" INTEGER,
    "operationsJson" JSONB NOT NULL,
    "outputStorageKey" TEXT,
    "outputFilename" TEXT,
    "outputMimeType" TEXT,
    "outputSizeBytes" BIGINT,
    "errorCode" TEXT,
    "errorMessage" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "EditJob_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "EditJob_deviceId_status_idx" ON "EditJob"("deviceId", "status");
CREATE INDEX "EditJob_deviceId_createdAt_idx" ON "EditJob"("deviceId", "createdAt");
CREATE INDEX "EditJob_deviceId_sourceDownloadJobId_idx" ON "EditJob"("deviceId", "sourceDownloadJobId");

ALTER TABLE "EditJob" ADD CONSTRAINT "EditJob_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
