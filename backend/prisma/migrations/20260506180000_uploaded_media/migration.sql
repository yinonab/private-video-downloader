-- CreateTable
CREATE TABLE "UploadedMedia" (
    "id" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'video',
    "originalFilename" TEXT,
    "mimeType" TEXT,
    "sizeBytes" BIGINT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "durationSeconds" INTEGER,
    "width" INTEGER,
    "height" INTEGER,
    "thumbnailStorageKey" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ready',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UploadedMedia_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "UploadedMedia_deviceId_idx" ON "UploadedMedia"("deviceId");

-- CreateIndex
CREATE INDEX "UploadedMedia_createdAt_idx" ON "UploadedMedia"("createdAt");

-- CreateIndex
CREATE INDEX "UploadedMedia_deviceId_createdAt_idx" ON "UploadedMedia"("deviceId", "createdAt");

-- AddForeignKey
ALTER TABLE "UploadedMedia" ADD CONSTRAINT "UploadedMedia_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
