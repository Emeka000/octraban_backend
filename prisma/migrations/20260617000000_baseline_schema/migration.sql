-- Baseline schema migration (see docs/database-ownership.md).
--
-- Replaces the previous 17 fragmented migrations, which together only ever
-- created 68 of the 218 tables in prisma/schema.prisma (the rest — including
-- basics like Ledger, Contract, Transaction, Event — had no migration at
-- all), and several of which created stale table names for models that had
-- since been refactored (e.g. "emergency_states" for a model that no longer
-- has @@map("emergency_states")). `prisma migrate deploy` against a fresh
-- database has never produced a schema matching prisma/schema.prisma.
--
-- Generated directly from prisma/schema.prisma via:
--   npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script

-- CreateEnum
CREATE TYPE "ReentrancyType" AS ENUM ('SIMPLE', 'CROSS_CONTRACT', 'MULTI_STEP', 'READ_ONLY', 'CROSS_FUNCTION', 'DESTRUCTIVE');

-- CreateEnum
CREATE TYPE "ReentrancySeverity" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

-- CreateEnum
CREATE TYPE "QueryFeedback" AS ENUM ('helpful', 'not_helpful', 'incorrect', 'partial');

-- CreateEnum
CREATE TYPE "ArchivalNodeStatus" AS ENUM ('active', 'inactive', 'jailed', 'slashed');

-- CreateEnum
CREATE TYPE "EpochStatus" AS ENUM ('storing', 'stored', 'verifying', 'verified', 'failed', 'removed');

-- CreateEnum
CREATE TYPE "ChallengeStatus" AS ENUM ('pending', 'issued', 'responded', 'verified', 'failed', 'expired');

-- CreateEnum
CREATE TYPE "RetrievalStatus" AS ENUM ('pending', 'routing', 'in_progress', 'completed', 'failed', 'refunded');

-- CreateTable
CREATE TABLE "Ledger" (
    "sequence" INTEGER NOT NULL,
    "hash" TEXT NOT NULL,
    "previousLedgerHash" TEXT,
    "closeTime" TIMESTAMP(3) NOT NULL,
    "txCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Ledger_pkey" PRIMARY KEY ("sequence")
);

-- CreateTable
CREATE TABLE "Contract" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "name" TEXT,
    "description" TEXT,
    "abi" JSONB,
    "functionSignatures" JSONB,
    "isToken" BOOLEAN NOT NULL DEFAULT false,
    "tokenSymbol" TEXT,
    "tokenName" TEXT,
    "tokenDecimals" INTEGER,
    "wasmHash" TEXT,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Contract_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WasmUpgradeHistory" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "previousHash" TEXT,
    "newHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "transactionHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "upgrader" TEXT,
    "upgraderAccountAgeLedgers" INTEGER,
    "changeClassification" TEXT,
    "changeSummary" TEXT,
    "diffStats" JSONB,
    "criticalFnChanges" TEXT[],
    "governanceType" TEXT,
    "signerCount" INTEGER,
    "threshold" INTEGER,
    "timelockSeconds" INTEGER,
    "daoProposalId" TEXT,
    "decentralizationScore" INTEGER,
    "suspiciousFlags" TEXT[],
    "isSuspicious" BOOLEAN NOT NULL DEFAULT false,
    "riskLevel" TEXT,

    CONSTRAINT "WasmUpgradeHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Transaction" (
    "id" TEXT NOT NULL,
    "hash" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "sourceAccount" TEXT NOT NULL,
    "contractAddress" TEXT,
    "functionName" TEXT,
    "functionArgs" JSONB,
    "rawXdr" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "flashLoanAlert" BOOLEAN,
    "humanReadable" TEXT,
    "feeCharged" TEXT,
    "sorobanResources" JSONB,
    "failureReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Transaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Event" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "topicSymbol" TEXT,
    "topics" JSONB NOT NULL,
    "data" JSONB NOT NULL,
    "decoded" JSONB,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "compacted" BOOLEAN,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Event_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EventDefinition" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "topicSymbol" TEXT NOT NULL,
    "humanTemplate" TEXT NOT NULL,
    "submittedBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "EventDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SessionAuthorization" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "hotSigner" TEXT,
    "authorizationType" TEXT NOT NULL,
    "startLedger" INTEGER NOT NULL,
    "expiryLedger" INTEGER NOT NULL,
    "allocatedBlocks" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SessionAuthorization_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IndexerState" (
    "id" TEXT NOT NULL DEFAULT 'singleton',
    "lastLedger" INTEGER NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "IndexerState_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RateLimitOverride" (
    "id" TEXT NOT NULL,
    "identifier" TEXT NOT NULL,
    "endpoint" TEXT NOT NULL DEFAULT '/',
    "max" INTEGER NOT NULL DEFAULT 100,
    "windowMs" INTEGER NOT NULL DEFAULT 60000,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RateLimitOverride_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReorgEvent" (
    "id" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "detectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expectedHash" TEXT NOT NULL,
    "actualHash" TEXT NOT NULL,
    "previousHash" TEXT NOT NULL,
    "rolledBackLedgers" INTEGER[],

    CONSTRAINT "ReorgEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LedgerGap" (
    "id" TEXT NOT NULL,
    "startSequence" INTEGER NOT NULL,
    "endSequence" INTEGER NOT NULL,
    "detectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "LedgerGap_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SacMapping" (
    "id" TEXT NOT NULL,
    "assetCode" TEXT NOT NULL,
    "assetIssuer" TEXT,
    "assetType" TEXT NOT NULL,
    "sacAddress" TEXT NOT NULL,
    "firstSeenLedger" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SacMapping_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SacTrustlineMapping" (
    "id" TEXT NOT NULL,
    "gAccount" TEXT NOT NULL,
    "sacAddress" TEXT NOT NULL,
    "assetCode" TEXT NOT NULL,
    "assetIssuer" TEXT,
    "assetType" TEXT NOT NULL DEFAULT 'credit_alphanum4',
    "trustlineLimit" TEXT NOT NULL DEFAULT '0',
    "isUnlimited" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'active',
    "transactionHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "changeTrustOpLedger" INTEGER,
    "changeTrustOpTxHash" TEXT,
    "origin" TEXT NOT NULL DEFAULT 'soroban',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SacTrustlineMapping_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VerificationJob" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT,
    "toolchain" TEXT NOT NULL DEFAULT 'soroban-cli@0.9.4',
    "status" TEXT NOT NULL DEFAULT 'pending',
    "uploadedHash" TEXT,
    "onChainWasmHash" TEXT,
    "compiledWasmHash" TEXT,
    "matched" BOOLEAN,
    "errorMsg" TEXT,
    "logs" TEXT,
    "sourceFiles" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VerificationJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractState" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "ledgerKey" TEXT NOT NULL,
    "keyType" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'Live',
    "liveUntilLedgerSeq" INTEGER,
    "lastSeenLedger" INTEGER NOT NULL,
    "restoredAtLedger" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ContractState_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RestorationLog" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "sourceAccount" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "feeCharged" TEXT,
    "restoredKeys" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RestorationLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FailedItem" (
    "id" TEXT NOT NULL,
    "itemType" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "ledger" INTEGER NOT NULL,
    "rawXdr" TEXT,
    "errorMsg" TEXT NOT NULL,
    "errorStack" TEXT,
    "context" JSONB,
    "retryCount" INTEGER NOT NULL DEFAULT 0,
    "dead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastTriedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FailedItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ApiKey" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMP(3),

    CONSTRAINT "ApiKey_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SmartWallet" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "walletType" TEXT NOT NULL,
    "signerCount" INTEGER,
    "threshold" INTEGER,
    "guardians" JSONB,
    "sessionKeys" JSONB,
    "authMethods" JSONB,
    "deployedAtLedger" INTEGER,
    "deployedByAccount" TEXT,
    "wasmHash" TEXT,
    "firstSeenLedger" INTEGER NOT NULL,
    "lastSeenLedger" INTEGER NOT NULL,
    "txCount" INTEGER NOT NULL DEFAULT 0,
    "sponsoredTxCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SmartWallet_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SponsoredTransaction" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "sponsorAccount" TEXT NOT NULL,
    "sourceAccount" TEXT NOT NULL,
    "walletAddress" TEXT,
    "feeCharged" TEXT,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SponsoredTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuthDecomposition" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "walletAddress" TEXT,
    "authTree" JSONB NOT NULL,
    "authMethods" JSONB NOT NULL,
    "signerCount" INTEGER NOT NULL DEFAULT 0,
    "hasSubCalls" BOOLEAN NOT NULL DEFAULT false,
    "humanReadable" TEXT,
    "ledgerSequence" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuthDecomposition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SanctionsList" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "sourceUrl" TEXT,
    "listVersion" TEXT NOT NULL,
    "listName" TEXT,
    "entityType" TEXT NOT NULL,
    "address" TEXT,
    "addressPattern" TEXT,
    "name" TEXT,
    "aliases" TEXT[],
    "program" TEXT,
    "country" TEXT,
    "idDocument" TEXT,
    "citizenship" TEXT[],
    "birthDate" TEXT,
    "placeOfBirth" TEXT,
    "title" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "addedToListAt" TIMESTAMP(3) NOT NULL,
    "importedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastModifiedAt" TIMESTAMP(3),

    CONSTRAINT "SanctionsList_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScreeningResult" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "txHash" TEXT,
    "screenedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "riskScore" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'clear',
    "matchType" TEXT,
    "matchedEntries" JSONB,
    "screeningMethod" TEXT NOT NULL DEFAULT 'real_time',
    "reviewerId" TEXT,
    "reviewAction" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "notes" TEXT,
    "durationMs" INTEGER,

    CONSTRAINT "ScreeningResult_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TravelRuleRecord" (
    "id" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "originatorVasp" TEXT,
    "beneficiaryVasp" TEXT,
    "originatorInfo" JSONB,
    "beneficiaryInfo" JSONB,
    "transferValue" TEXT NOT NULL,
    "thresholdExceeded" BOOLEAN NOT NULL DEFAULT false,
    "travelRuleStatus" TEXT NOT NULL DEFAULT 'pending_verification',
    "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verifiedAt" TIMESTAMP(3),

    CONSTRAINT "TravelRuleRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ComplianceReport" (
    "id" TEXT NOT NULL,
    "reportType" TEXT NOT NULL,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "format" TEXT NOT NULL DEFAULT 'pdf',
    "fileUrl" TEXT,
    "fileData" BYTEA,
    "parameters" JSONB,
    "reportData" JSONB,
    "createdBy" TEXT,

    CONSTRAINT "ComplianceReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractResourceMetric" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "memoryUsageBytes" INTEGER NOT NULL,
    "cpuInstructions" INTEGER NOT NULL,
    "storageFootprint" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ContractResourceMetric_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TranslationKey" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "defaultText" TEXT NOT NULL,
    "context" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TranslationKey_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Translation" (
    "id" TEXT NOT NULL,
    "keyId" TEXT NOT NULL,
    "language" TEXT NOT NULL,
    "translatedText" TEXT NOT NULL,
    "approvedBy" TEXT,
    "approvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Translation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedChannel" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "category" TEXT,
    "schema" JSONB,
    "retentionDays" INTEGER,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeedChannel_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedMessage" (
    "id" TEXT NOT NULL,
    "channelName" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "sequence" INTEGER NOT NULL DEFAULT 0,
    "indexedAt" TIMESTAMP(3),
    "ledgerSequence" INTEGER,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeedMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeedSubscription" (
    "id" TEXT NOT NULL,
    "channelName" TEXT NOT NULL,
    "deliveryType" TEXT NOT NULL,
    "deliveryConfig" JSONB,
    "userId" TEXT,
    "filters" JSONB,
    "batchSize" INTEGER,
    "maxRatePerSecond" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'active',
    "lastDeliveryAt" TIMESTAMP(3),
    "lastError" TEXT,
    "totalDelivered" INTEGER,
    "totalFailed" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeedSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EmergencyState" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "isPaused" BOOLEAN NOT NULL DEFAULT false,
    "currentPauseId" TEXT,
    "totalPauseCount" INTEGER NOT NULL DEFAULT 0,
    "totalPausedSeconds" BIGINT NOT NULL DEFAULT 0,
    "lastPauseDurationSeconds" BIGINT,
    "pauserType" VARCHAR(30),
    "decentralizationScore" DECIMAL(5,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmergencyState_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PauseEvent" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "eventType" VARCHAR(20) NOT NULL,
    "pauserAddress" VARCHAR(56),
    "reason" TEXT,
    "txHash" VARCHAR(64) NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "durationSeconds" BIGINT,
    "gasCost" BIGINT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PauseEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PauserAnalysis" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "pauserType" VARCHAR(30) NOT NULL,
    "pauserAddresses" TEXT[],
    "unpauserAddresses" TEXT[],
    "threshold" INTEGER,
    "totalSigners" INTEGER,
    "timelockDelaySeconds" BIGINT,
    "governanceContract" VARCHAR(56),
    "automaticTriggers" JSONB,
    "analysisMethod" VARCHAR(30),
    "lastAnalyzed" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PauserAnalysis_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecoveryAnalysis" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "hasFundRecovery" BOOLEAN NOT NULL DEFAULT false,
    "fundRecoveryFunctions" TEXT[],
    "hasUpgradeCapability" BOOLEAN NOT NULL DEFAULT false,
    "upgradeFunctions" TEXT[],
    "hasMigrationCapability" BOOLEAN NOT NULL DEFAULT false,
    "migrationFunctions" TEXT[],
    "hasStateRollback" BOOLEAN NOT NULL DEFAULT false,
    "rollbackFunctions" TEXT[],
    "recoveryRobustnessScore" DECIMAL(5,2),
    "analysisDetails" JSONB,
    "lastAnalyzed" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RecoveryAnalysis_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AlertConfiguration" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "contractAddress" VARCHAR(56),
    "name" VARCHAR(255),
    "alertType" VARCHAR(50) NOT NULL,
    "conditions" JSONB,
    "channels" JSONB NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "cooldownMinutes" INTEGER NOT NULL DEFAULT 60,
    "lastTriggeredAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AlertConfiguration_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IncidentReport" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "severity" VARCHAR(20) NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'open',
    "pauseEventId" TEXT,
    "title" VARCHAR(255) NOT NULL,
    "description" TEXT,
    "timeline" JSONB,
    "affectedUsersEstimate" BIGINT,
    "affectedTvlEstimate" DECIMAL(30,0),
    "rootCause" TEXT,
    "resolutionNotes" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IncidentReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IncidentComment" (
    "id" TEXT NOT NULL,
    "incidentId" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IncidentComment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProtocolHealthScore" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "protocolName" VARCHAR(255),
    "totalPauses30d" INTEGER NOT NULL DEFAULT 0,
    "totalPauses90d" INTEGER NOT NULL DEFAULT 0,
    "avgPauseDuration30d" BIGINT,
    "totalDowntime30d" BIGINT,
    "lastPauseDate" TIMESTAMP(3),
    "recoveryScore" DECIMAL(5,2),
    "decentralizationScore" DECIMAL(5,2),
    "healthScore" DECIMAL(5,2),
    "riskLevel" VARCHAR(20),
    "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProtocolHealthScore_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StellarAccount" (
    "id" TEXT NOT NULL,
    "address" VARCHAR(56) NOT NULL,
    "xlmBalance" DECIMAL(30,7) NOT NULL DEFAULT 0,
    "buyingLiabilities" DECIMAL(30,7) NOT NULL DEFAULT 0,
    "sellingLiabilities" DECIMAL(30,7) NOT NULL DEFAULT 0,
    "sequenceNumber" BIGINT,
    "subentryCount" INTEGER NOT NULL DEFAULT 0,
    "inflationDestination" VARCHAR(56),
    "homeDomain" VARCHAR(255),
    "homeDomainVerified" BOOLEAN NOT NULL DEFAULT false,
    "flags" JSONB,
    "thresholds" JSONB,
    "numSigners" INTEGER NOT NULL DEFAULT 0,
    "numTrustlines" INTEGER NOT NULL DEFAULT 0,
    "numDataEntries" INTEGER NOT NULL DEFAULT 0,
    "numClaimableBalances" INTEGER NOT NULL DEFAULT 0,
    "isActivated" BOOLEAN NOT NULL DEFAULT false,
    "firstSeen" TIMESTAMP(3),
    "lastActivity" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StellarAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AccountTrustline" (
    "id" BIGSERIAL NOT NULL,
    "accountId" TEXT NOT NULL,
    "assetCode" VARCHAR(12) NOT NULL,
    "assetIssuer" VARCHAR(56) NOT NULL,
    "balance" DECIMAL(30,7) NOT NULL DEFAULT 0,
    "limitAmount" DECIMAL(30,7),
    "authorized" BOOLEAN NOT NULL DEFAULT false,
    "authorizedToMaintainLiabilities" BOOLEAN NOT NULL DEFAULT false,
    "clawbackBalanceSet" BOOLEAN NOT NULL DEFAULT false,
    "isLiquidityPoolShare" BOOLEAN NOT NULL DEFAULT false,
    "lastModified" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AccountTrustline_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AccountSigner" (
    "id" BIGSERIAL NOT NULL,
    "accountId" TEXT NOT NULL,
    "signerKey" VARCHAR(56) NOT NULL,
    "signerType" VARCHAR(30) NOT NULL,
    "weight" INTEGER NOT NULL,
    "sponsor" VARCHAR(56),
    "lastModified" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AccountSigner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StellarAsset" (
    "id" TEXT NOT NULL,
    "assetCode" VARCHAR(12) NOT NULL,
    "assetIssuer" VARCHAR(56) NOT NULL,
    "assetType" VARCHAR(20) NOT NULL,
    "totalSupply" DECIMAL(30,7) NOT NULL DEFAULT 0,
    "numHolders" INTEGER NOT NULL DEFAULT 0,
    "numTrustlines" INTEGER NOT NULL DEFAULT 0,
    "volume24h" DECIMAL(30,7) NOT NULL DEFAULT 0,
    "trades24h" INTEGER NOT NULL DEFAULT 0,
    "isAnchored" BOOLEAN NOT NULL DEFAULT false,
    "anchorName" VARCHAR(255),
    "homeDomain" VARCHAR(255),
    "isBridgedToSoroban" BOOLEAN NOT NULL DEFAULT false,
    "sorobanContract" VARCHAR(56),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StellarAsset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UnifiedTransaction" (
    "id" TEXT NOT NULL,
    "sourceAccount" VARCHAR(56) NOT NULL,
    "network" VARCHAR(20) NOT NULL,
    "txHash" VARCHAR(64) NOT NULL,
    "type" VARCHAR(30) NOT NULL,
    "subType" VARCHAR(50),
    "amount" DECIMAL(30,7),
    "assetCode" VARCHAR(12),
    "assetIssuer" VARCHAR(56),
    "destination" VARCHAR(56),
    "fee" DECIMAL(30,7),
    "memoType" VARCHAR(20),
    "memoContent" TEXT,
    "successful" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL,
    "ledgerSequence" INTEGER,
    "operations" JSONB,

    CONSTRAINT "UnifiedTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnchorsRegistry" (
    "id" TEXT NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "homeDomain" VARCHAR(255) NOT NULL,
    "address" VARCHAR(56),
    "assets" JSONB NOT NULL,
    "regions" TEXT[],
    "kycRequired" BOOLEAN NOT NULL DEFAULT false,
    "kycTypes" TEXT[],
    "fees" JSONB,
    "limits" JSONB,
    "supportedSeps" TEXT[],
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "rating" DECIMAL(3,2) NOT NULL DEFAULT 0,
    "reviewCount" INTEGER NOT NULL DEFAULT 0,
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnchorsRegistry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnchorReview" (
    "id" TEXT NOT NULL,
    "anchorId" TEXT NOT NULL,
    "reviewer" VARCHAR(56) NOT NULL,
    "rating" DECIMAL(3,2) NOT NULL,
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnchorReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BridgedAsset" (
    "id" TEXT NOT NULL,
    "classicAssetCode" VARCHAR(12) NOT NULL,
    "classicAssetIssuer" VARCHAR(56) NOT NULL,
    "sorobanContract" VARCHAR(56) NOT NULL,
    "bridgeProtocol" VARCHAR(50) NOT NULL,
    "bridgeContract" VARCHAR(56),
    "totalSupplyClassic" DECIMAL(30,7),
    "totalSupplySoroban" DECIMAL(30,7),
    "circulationClassic" DECIMAL(30,7),
    "circulationSoroban" DECIMAL(30,7),
    "lockedInBridge" DECIMAL(30,7),
    "totalBridgedVolume" DECIMAL(30,0),
    "bridgeFee" DECIMAL(5,4),
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BridgedAsset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StellarNetworkHealth" (
    "id" BIGSERIAL NOT NULL,
    "nodeCount" INTEGER,
    "organizationCount" INTEGER,
    "countriesCount" INTEGER,
    "consensusRoundTimeMs" INTEGER,
    "ledgerCloseTimeMs" INTEGER,
    "latestLedgerSequence" BIGINT,
    "protocolVersion" INTEGER,
    "scpMessagesPerSecond" DECIMAL(10,2),
    "networkQuorumSet" JSONB,
    "topOrganizations" JSONB,
    "collectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StellarNetworkHealth_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ComposedTransaction" (
    "id" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "ledgerSeq" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "contractCalls" JSONB,
    "callGraph" JSONB,
    "safetyScore" DOUBLE PRECISION,
    "riskLevel" TEXT,
    "analysisStatus" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "patterns" JSONB,

    CONSTRAINT "ComposedTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompositionPattern" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "riskRating" TEXT NOT NULL DEFAULT 'medium_risk',
    "requiredCalls" INTEGER NOT NULL DEFAULT 2,
    "detectionRules" JSONB,
    "safeIf" JSONB,
    "mitigationGuide" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CompositionPattern_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompositionPatternInstance" (
    "id" TEXT NOT NULL,
    "txId" TEXT NOT NULL,
    "patternId" TEXT NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL,
    "details" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CompositionPatternInstance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractComposability" (
    "id" TEXT NOT NULL,
    "contractId" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "composedWith" JSONB,
    "compositionCount" INTEGER NOT NULL DEFAULT 0,
    "uniqueCallers" INTEGER NOT NULL DEFAULT 0,
    "uniqueCallees" INTEGER NOT NULL DEFAULT 0,
    "avgCompositionDepth" DOUBLE PRECISION,
    "safetyScoreAvg" DOUBLE PRECISION,
    "riskIncidents" INTEGER NOT NULL DEFAULT 0,
    "lastAnalyzed" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ContractComposability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CompositionAlert" (
    "id" TEXT NOT NULL,
    "txHash" TEXT,
    "contractAddress" TEXT,
    "patternId" TEXT,
    "severity" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "exploitDetected" BOOLEAN NOT NULL DEFAULT false,
    "mitigated" BOOLEAN NOT NULL DEFAULT false,
    "mitigationPatch" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "CompositionAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ComposabilityStaticAnalysis" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "externalCalls" JSONB,
    "callGraph" JSONB,
    "circularDeps" JSONB,
    "hasUnboundedRecursion" BOOLEAN NOT NULL DEFAULT false,
    "maxCallDepth" INTEGER NOT NULL DEFAULT 0,
    "analysisVersion" TEXT NOT NULL DEFAULT '1.0',
    "analyzedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ComposabilityStaticAnalysis_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ComposabilityVerification" (
    "id" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "atomicity" BOOLEAN NOT NULL DEFAULT false,
    "authorization" BOOLEAN NOT NULL DEFAULT false,
    "stateConsistency" BOOLEAN NOT NULL DEFAULT false,
    "reentrancyFree" BOOLEAN NOT NULL DEFAULT false,
    "oracleFreshness" BOOLEAN NOT NULL DEFAULT false,
    "atomicityScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "authorizationScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "stateScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "reentrancyScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "oracleScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "proofData" JSONB,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ComposabilityVerification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ComposabilityFuzzCampaign" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'running',
    "totalCases" INTEGER NOT NULL DEFAULT 0,
    "unsafeFound" INTEGER NOT NULL DEFAULT 0,
    "falsePositives" INTEGER NOT NULL DEFAULT 0,
    "coveragePct" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "findings" JSONB,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ComposabilityFuzzCampaign_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ComposabilityExploit" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "patternCategory" TEXT NOT NULL,
    "cveId" TEXT,
    "affectedContracts" TEXT[],
    "exploitTxHashes" TEXT[],
    "advisoryUrl" TEXT,
    "severity" TEXT NOT NULL,
    "discoveredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ComposabilityExploit_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EcosystemComposabilityIndex" (
    "id" TEXT NOT NULL,
    "score" DOUBLE PRECISION NOT NULL,
    "compositionDiversity" INTEGER NOT NULL DEFAULT 0,
    "avgSafetyScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "exploitIncidentRate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "protocolInterconnectivity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalContracts" INTEGER NOT NULL DEFAULT 0,
    "totalComposedTx" INTEGER NOT NULL DEFAULT 0,
    "computedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EcosystemComposabilityIndex_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MevVictim" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "totalLossUsd" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "incidentCount" INTEGER NOT NULL DEFAULT 0,
    "lastIncidentAt" TIMESTAMP(3),
    "firstIncidentAt" TIMESTAMP(3),
    "protectionScore" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MevVictim_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MevAttacker" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "totalProfitUsd" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "attackCount" INTEGER NOT NULL DEFAULT 0,
    "favoriteType" TEXT,
    "lastAttackAt" TIMESTAMP(3),
    "firstSeen" TIMESTAMP(3),
    "isContract" BOOLEAN NOT NULL DEFAULT false,
    "tags" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MevAttacker_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MevEvent" (
    "id" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "ledgerSeq" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "mevType" TEXT NOT NULL,
    "victimAddress" TEXT,
    "attackerAddress" TEXT,
    "protocolAddress" TEXT,
    "tokenIn" TEXT,
    "tokenOut" TEXT,
    "amountIn" TEXT,
    "amountOut" TEXT,
    "profitAmount" TEXT,
    "profitUsd" DOUBLE PRECISION,
    "lossAmount" TEXT,
    "lossUsd" DOUBLE PRECISION,
    "txOrder" JSONB,
    "confidence" DOUBLE PRECISION NOT NULL,
    "details" JSONB,
    "flashLoanAlert" BOOLEAN,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MevEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProtocolMevResistance" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "contractName" TEXT,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 50,
    "commitReveal" BOOLEAN NOT NULL DEFAULT false,
    "batchAuctions" BOOLEAN NOT NULL DEFAULT false,
    "slippageDefault" DOUBLE PRECISION,
    "privateMempool" BOOLEAN NOT NULL DEFAULT false,
    "encryptedTxs" BOOLEAN NOT NULL DEFAULT false,
    "mevExtractedUsd" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalIncidents" INTEGER NOT NULL DEFAULT 0,
    "lastIncidentAt" TIMESTAMP(3),
    "scoreHistory" JSONB,
    "recommendations" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProtocolMevResistance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MevAlert" (
    "id" TEXT NOT NULL,
    "alertType" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "txHash" TEXT,
    "victimAddress" TEXT,
    "protocolAddress" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "estimatedLoss" DOUBLE PRECISION,
    "recommendedAction" TEXT,
    "acknowledged" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "MevAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BillingPlan" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "requestsPerDay" INTEGER NOT NULL,
    "requestsPerMonth" INTEGER NOT NULL,
    "priceMonthly" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "features" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BillingPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Developer" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,
    "passwordHash" TEXT,
    "githubId" TEXT,
    "walletAddress" TEXT,
    "planId" TEXT,
    "role" TEXT NOT NULL DEFAULT 'user',
    "emailVerified" BOOLEAN NOT NULL DEFAULT false,
    "mfaEnabled" BOOLEAN NOT NULL DEFAULT false,
    "mfaSecret" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Developer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DevApiKey" (
    "id" TEXT NOT NULL,
    "developerId" TEXT NOT NULL,
    "keyPrefix" TEXT NOT NULL,
    "keyHash" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "permissions" JSONB NOT NULL DEFAULT '{}',
    "allowedIps" JSONB,
    "allowedDomains" JSONB,
    "allowedEndpoints" JSONB,
    "tier" TEXT NOT NULL DEFAULT 'free',
    "rateLimitOverride" INTEGER,
    "revokedAt" TIMESTAMP(3),
    "usageCount" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMP(3),
    "lastUsedAt" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DevApiKey_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DevWebhook" (
    "id" TEXT NOT NULL,
    "developerId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "secret" TEXT NOT NULL,
    "events" JSONB NOT NULL DEFAULT '[]',
    "retryPolicy" JSONB,
    "headers" JSONB,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "storeResponseBody" BOOLEAN NOT NULL DEFAULT true,
    "responseRetentionDays" INTEGER NOT NULL DEFAULT 90,
    "lastDeliveryAt" TIMESTAMP(3),
    "lastDeliveryStatus" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DevWebhook_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DevWebhookDelivery" (
    "id" TEXT NOT NULL,
    "webhookId" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "statusCode" INTEGER,
    "responseBody" TEXT,
    "durationMs" INTEGER,
    "attempt" INTEGER NOT NULL DEFAULT 1,
    "delivered" BOOLEAN NOT NULL DEFAULT false,
    "deliveredAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DevWebhookDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UsageRecord" (
    "id" TEXT NOT NULL,
    "developerId" TEXT NOT NULL,
    "apiKeyId" TEXT,
    "endpoint" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "statusCode" INTEGER NOT NULL,
    "latencyMs" INTEGER NOT NULL DEFAULT 0,
    "ipAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UsageRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ScheduledOperation" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "timerType" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "functionName" TEXT NOT NULL,
    "description" TEXT,
    "triggerTime" TIMESTAMP(3) NOT NULL,
    "windowStart" TIMESTAMP(3),
    "windowEnd" TIMESTAMP(3),
    "intervalSeconds" INTEGER,
    "recurrenceCount" INTEGER,
    "eventsExecuted" INTEGER NOT NULL DEFAULT 0,
    "parameters" JSONB,
    "sourceTx" TEXT,
    "createdBy" TEXT,
    "detectedAt" TIMESTAMP(3) NOT NULL,
    "lastExecutedAt" TIMESTAMP(3),
    "nextTriggerAt" TIMESTAMP(3),

    CONSTRAINT "ScheduledOperation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VestingSchedule" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "tokenAddress" TEXT NOT NULL,
    "tokenSymbol" TEXT,
    "beneficiary" TEXT NOT NULL,
    "totalAmount" DECIMAL(65,30) NOT NULL,
    "cliffDate" TIMESTAMP(3),
    "cliffAmount" DECIMAL(65,30),
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "vestingType" TEXT NOT NULL,
    "periodSeconds" INTEGER,
    "amountPerPeriod" DECIMAL(65,30),
    "periodsTotal" INTEGER,
    "nextUnlockDate" TIMESTAMP(3),
    "nextUnlockAmount" DECIMAL(65,30),
    "totalUnlocked" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "totalClaimed" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL,
    "sourceTx" TEXT,
    "detectedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VestingSchedule_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GovernanceTimelock" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "proposalId" TEXT,
    "title" TEXT,
    "description" TEXT,
    "proposer" TEXT NOT NULL,
    "executor" TEXT,
    "targets" JSONB NOT NULL,
    "values" JSONB NOT NULL,
    "calldatas" JSONB NOT NULL,
    "operationHash" TEXT,
    "queuedAt" TIMESTAMP(3) NOT NULL,
    "minDelay" INTEGER NOT NULL,
    "executionTime" TIMESTAMP(3) NOT NULL,
    "expiryTime" TIMESTAMP(3),
    "status" TEXT NOT NULL,
    "executedTx" TEXT,
    "cancelledBy" TEXT,
    "gracePeriod" INTEGER,

    CONSTRAINT "GovernanceTimelock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CronJob" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "cronExpression" TEXT NOT NULL,
    "functionName" TEXT NOT NULL,
    "functionArgs" JSONB NOT NULL,
    "description" TEXT,
    "lastRunAt" TIMESTAMP(3),
    "nextRunAt" TIMESTAMP(3),
    "totalRuns" INTEGER NOT NULL DEFAULT 0,
    "successfulRuns" INTEGER NOT NULL DEFAULT 0,
    "failedRuns" INTEGER NOT NULL DEFAULT 0,
    "maxRuns" INTEGER,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CronJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CronExecution" (
    "id" TEXT NOT NULL,
    "cronJobId" TEXT NOT NULL,
    "executedAt" TIMESTAMP(3) NOT NULL,
    "success" BOOLEAN NOT NULL,
    "txHash" TEXT,
    "errorMessage" TEXT,
    "gasUsed" INTEGER,
    "duration" INTEGER,

    CONSTRAINT "CronExecution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TimerAlert" (
    "id" TEXT NOT NULL,
    "scheduledOpId" TEXT,
    "alertType" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "triggerTime" TIMESTAMP(3) NOT NULL,
    "delivered" BOOLEAN NOT NULL DEFAULT false,
    "acknowledged" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "TimerAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DexPool" (
    "id" TEXT NOT NULL,
    "contractAddress" VARCHAR(56) NOT NULL,
    "dexName" VARCHAR(100) NOT NULL,
    "poolType" VARCHAR(30) NOT NULL,
    "aprPct" DOUBLE PRECISION,
    "feeBps" INTEGER,
    "feeTier" DECIMAL(5,4),
    "fees24h" DECIMAL(30,0),
    "fees24hUsd" DECIMAL(65,30),
    "firstSeenLedger" INTEGER,
    "ilRiskScore" DOUBLE PRECISION,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastEventLedger" INTEGER,
    "lastSyncedAt" TIMESTAMP(3),
    "pairKey" TEXT,
    "poolAddress" TEXT,
    "priceAUsd" DECIMAL(65,30),
    "priceBUsd" DECIMAL(65,30),
    "protocol" TEXT,
    "reserveA" DECIMAL(65,30),
    "reserveB" DECIMAL(65,30),
    "tokenA" VARCHAR(56) NOT NULL,
    "tokenADecimals" INTEGER,
    "tokenASymbol" VARCHAR(20),
    "tokenB" VARCHAR(56) NOT NULL,
    "tokenBDecimals" INTEGER,
    "tokenBSymbol" VARCHAR(20),
    "totalLiquidity" DECIMAL(30,0),
    "tvlUsd" DECIMAL(65,30),
    "volume1hUsd" DECIMAL(65,30),
    "volume24h" DECIMAL(30,0),
    "volume24hUsd" DECIMAL(65,30),
    "volume7dUsd" DECIMAL(65,30),
    "volume30dUsd" DECIMAL(65,30),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DexPool_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PoolPrice" (
    "id" BIGSERIAL NOT NULL,
    "poolId" TEXT NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "reserveA" DECIMAL(30,0) NOT NULL,
    "reserveB" DECIMAL(30,0) NOT NULL,
    "spotPrice" DECIMAL(30,18) NOT NULL,
    "twap1m" DECIMAL(30,18),
    "twap5m" DECIMAL(30,18),
    "twap1h" DECIMAL(30,18),
    "vwap" DECIMAL(30,18),
    "tick" INTEGER,
    "sqrtPrice" DECIMAL(40,0),

    CONSTRAINT "PoolPrice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PriceDeviation" (
    "id" BIGSERIAL NOT NULL,
    "tokenA" VARCHAR(56) NOT NULL,
    "tokenB" VARCHAR(56) NOT NULL,
    "poolIdA" TEXT NOT NULL,
    "poolIdB" TEXT NOT NULL,
    "priceA" DECIMAL(30,18) NOT NULL,
    "priceB" DECIMAL(30,18) NOT NULL,
    "deviationPercentage" DECIMAL(10,4) NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "blockNumber" BIGINT NOT NULL,

    CONSTRAINT "PriceDeviation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArbitrageOpportunity" (
    "id" TEXT NOT NULL,
    "pair" VARCHAR(50) NOT NULL,
    "pairKey" TEXT,
    "tokenA" VARCHAR(56) NOT NULL,
    "tokenB" VARCHAR(56) NOT NULL,
    "type" VARCHAR(30) NOT NULL,
    "buyPoolId" TEXT,
    "sellPoolId" TEXT,
    "buyPrice" DECIMAL(30,18) NOT NULL,
    "sellPrice" DECIMAL(30,18) NOT NULL,
    "profitPercentage" DECIMAL(10,4) NOT NULL,
    "profitEstimate" DECIMAL(30,0),
    "capitalRequired" DECIMAL(30,0),
    "confidence" DECIMAL(5,4),
    "route" JSONB NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "detectedAt" TIMESTAMP(3) NOT NULL,
    "expiredAt" TIMESTAMP(3),
    "executedAt" TIMESTAMP(3),
    "executionTxHash" VARCHAR(64),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ArbitrageOpportunity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MevOpportunityScore" (
    "id" TEXT NOT NULL,
    "opportunityId" TEXT NOT NULL,
    "profitabilityScore" DECIMAL(5,2),
    "capitalEfficiency" DECIMAL(10,4),
    "speedRequirement" VARCHAR(20),
    "competitionLevel" VARCHAR(20),
    "slippageRisk" DECIMAL(5,2),
    "frontrunningRisk" DECIMAL(5,2),
    "overallScore" DECIMAL(5,2),
    "recommendation" VARCHAR(50),
    "scoredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MevOpportunityScore_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArbitrageExecution" (
    "id" TEXT NOT NULL,
    "opportunityId" TEXT NOT NULL,
    "searcherAddress" VARCHAR(56),
    "txHash" VARCHAR(64) NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "capitalUsed" DECIMAL(30,0),
    "grossProfit" DECIMAL(30,0),
    "gasCost" DECIMAL(30,0),
    "netProfit" DECIMAL(30,0),
    "executionTimeMs" INTEGER,
    "success" BOOLEAN NOT NULL,
    "failureReason" TEXT,
    "simulationResults" JSONB,
    "executedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ArbitrageExecution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArbitrageBot" (
    "id" TEXT NOT NULL,
    "address" VARCHAR(56) NOT NULL,
    "firstSeen" TIMESTAMP(3) NOT NULL,
    "lastSeen" TIMESTAMP(3) NOT NULL,
    "totalTrades" INTEGER NOT NULL DEFAULT 0,
    "successfulTrades" INTEGER NOT NULL DEFAULT 0,
    "failedTrades" INTEGER NOT NULL DEFAULT 0,
    "totalProfit" DECIMAL(30,0) NOT NULL DEFAULT 0,
    "totalGasSpent" DECIMAL(30,0) NOT NULL DEFAULT 0,
    "avgProfitPerTrade" DECIMAL(30,0),
    "successRate" DECIMAL(5,4),
    "preferredPairs" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "preferredDexs" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "avgCapitalPerTrade" DECIMAL(30,0),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ArbitrageBot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandwichAttack" (
    "id" TEXT NOT NULL,
    "pair" VARCHAR(50) NOT NULL,
    "dex" VARCHAR(100) NOT NULL,
    "victimTx" VARCHAR(64) NOT NULL,
    "victimAddress" VARCHAR(56) NOT NULL,
    "victimSlippage" DECIMAL(10,4) NOT NULL,
    "victimLoss" DECIMAL(30,0),
    "attackerAddress" VARCHAR(56) NOT NULL,
    "attackerProfit" DECIMAL(30,0),
    "frontRunTx" VARCHAR(64) NOT NULL,
    "backRunTx" VARCHAR(64) NOT NULL,
    "blockNumber" BIGINT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SandwichAttack_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ArbitrageAlert" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "conditions" JSONB NOT NULL,
    "channels" JSONB NOT NULL,
    "cooldownSeconds" INTEGER NOT NULL DEFAULT 30,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastTriggeredAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ArbitrageAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProtocolEconomicsSnapshot" (
    "id" TEXT NOT NULL,
    "bucket" TEXT NOT NULL,
    "bucketStart" TIMESTAMP(3) NOT NULL,
    "bucketEnd" TIMESTAMP(3) NOT NULL,
    "txCount" INTEGER NOT NULL,
    "totalFees" DOUBLE PRECISION NOT NULL,
    "feeBurn" DOUBLE PRECISION NOT NULL,
    "networkRevenue" DOUBLE PRECISION NOT NULL,
    "avgFee" DOUBLE PRECISION NOT NULL,
    "successCount" INTEGER NOT NULL,
    "failedCount" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProtocolEconomicsSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeatureDefinition" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "category" TEXT,
    "unit" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FeatureDefinition_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FeatureValue" (
    "id" TEXT NOT NULL,
    "featureId" TEXT NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "ledger" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FeatureValue_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PredictionScenario" (
    "id" TEXT NOT NULL,
    "scenarioName" TEXT NOT NULL,
    "perturbations" JSONB,
    "horizon" INTEGER NOT NULL,
    "baseForecastId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PredictionScenario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PredictiveApiKey" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "tier" TEXT NOT NULL DEFAULT 'free',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "lastUsedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PredictiveApiKey_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AmmPool" (
    "id" TEXT NOT NULL,
    "poolAddress" TEXT NOT NULL,
    "assetAAddress" TEXT NOT NULL,
    "assetBAddress" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AmmPool_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnonymitySetSnapshot" (
    "id" TEXT NOT NULL,
    "protocol" TEXT NOT NULL,
    "setSize" INTEGER NOT NULL,
    "effectiveSetSize" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnonymitySetSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Attestation" (
    "id" TEXT NOT NULL,
    "uid" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "chainId" TEXT NOT NULL,
    "schemaId" TEXT NOT NULL,
    "attester" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "recipient" TEXT NOT NULL,
    "revoked" BOOLEAN NOT NULL,
    "signature" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "blockNumber" INTEGER NOT NULL,
    "data" JSONB NOT NULL,
    "verified" BOOLEAN NOT NULL,
    "verificationMsg" TEXT,
    "issuedAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Attestation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "actor" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "previousState" JSONB,
    "newState" JSONB,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BackfillRequest" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "channelName" TEXT NOT NULL,
    "startTime" TIMESTAMP(3) NOT NULL,
    "endTime" TIMESTAMP(3) NOT NULL,
    "format" TEXT NOT NULL,
    "filters" JSONB,
    "status" TEXT NOT NULL,
    "progress" DOUBLE PRECISION,
    "fileUrl" TEXT,
    "fileSizeBytes" INTEGER,
    "recordCount" INTEGER,
    "completedAt" TIMESTAMP(3),
    "errorMessage" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BackfillRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Bn254GasExemption" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "bn254Ops" TEXT,
    "opCount" INTEGER,
    "feeCharged" TEXT,
    "estimatedWasmFee" TEXT,
    "stroopSavings" TEXT,
    "savingsPct" DOUBLE PRECISION,
    "cpuInstructions" INTEGER,
    "msmComplexity" TEXT,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Bn254GasExemption_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CommodityDualSignerLog" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "commodityType" TEXT NOT NULL,
    "commodityCode" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "traderAddress" TEXT NOT NULL,
    "primarySignerAddress" TEXT NOT NULL,
    "secondarySignerAddress" TEXT NOT NULL,
    "quantity" TEXT,
    "unit" TEXT,
    "notionalValueUsd" TEXT,
    "regulatoryJurisdiction" TEXT,
    "expiresAt" TIMESTAMP(3),
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "primarySigned" BOOLEAN,
    "secondarySigned" BOOLEAN,
    "bothSigned" BOOLEAN,
    "complianceStatus" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CommodityDualSignerLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractBenchmarkSnapshot" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "functionName" TEXT NOT NULL,
    "avgCpu" DOUBLE PRECISION,
    "avgMemory" DOUBLE PRECISION,
    "avgFeeStroops" DOUBLE PRECISION,
    "samples" INTEGER NOT NULL,
    "fees" JSONB,
    "cpus" JSONB,
    "mems" JSONB,
    "txs" JSONB,
    "ledgerSequence" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContractBenchmarkSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractFactory" (
    "id" TEXT NOT NULL,
    "parentContractAddress" TEXT NOT NULL,
    "childContractAddress" TEXT NOT NULL,
    "creationTransactionHash" TEXT NOT NULL,
    "creationLedgerSequence" INTEGER NOT NULL,
    "creationTimestamp" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContractFactory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ContractTemplate" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ContractTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DeAnonymizationFinding" (
    "id" TEXT NOT NULL,
    "sourceTx" TEXT NOT NULL,
    "technique" TEXT NOT NULL,
    "confidence" DOUBLE PRECISION,
    "targetAddress" TEXT NOT NULL,
    "detectedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeAnonymizationFinding_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DerivedMetric" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DerivedMetric_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DtccSettlementBridge" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "dtccSettlementId" TEXT NOT NULL,
    "securityId" TEXT NOT NULL,
    "securityType" TEXT NOT NULL,
    "sellerAddress" TEXT NOT NULL,
    "buyerAddress" TEXT NOT NULL,
    "quantity" TEXT,
    "settlementAmount" TEXT,
    "currency" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "settlementDate" TIMESTAMP(3),
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "settlementStatus" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DtccSettlementBridge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Endorsement" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "chainId" TEXT NOT NULL,
    "endorser" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "weight" DOUBLE PRECISION,
    "timestamp" TIMESTAMP(3),
    "transactionHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Endorsement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ExportJob" (
    "id" TEXT NOT NULL,
    "developerId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "progress" DOUBLE PRECISION,
    "exportType" TEXT,
    "filePath" TEXT,
    "fileUrl" TEXT,
    "filters" JSONB,
    "errorMsg" TEXT,
    "errorMessage" TEXT,
    "rowCount" INTEGER,
    "completedAt" TIMESTAMP(3),
    "totalRows" INTEGER,
    "processedRows" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ExportJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FreezeViolation" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "frozenKeys" JSONB,
    "severity" TEXT,
    "resolution" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FreezeViolation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FrozenLedgerKey" (
    "id" TEXT NOT NULL,
    "ledgerKey" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL,
    "frozenAtLedger" INTEGER NOT NULL,
    "frozenAtTime" TIMESTAMP(3) NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FrozenLedgerKey_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FuzzFinding" (
    "id" TEXT NOT NULL,
    "runId" TEXT NOT NULL,
    "findingType" TEXT NOT NULL,
    "description" TEXT,
    "fuzzRunId" TEXT,
    "severity" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FuzzFinding_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FuzzRun" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "contractId" TEXT,
    "status" TEXT NOT NULL,
    "totalCases" INTEGER NOT NULL,
    "unsafeFound" INTEGER NOT NULL,
    "coveragePct" DOUBLE PRECISION,
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FuzzRun_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GasAnalyticsSnapshot" (
    "id" TEXT NOT NULL,
    "bucket" TEXT NOT NULL,
    "bucketStart" TIMESTAMP(3) NOT NULL,
    "bucketEnd" TIMESTAMP(3) NOT NULL,
    "avgFee" DOUBLE PRECISION,
    "medianFee" DOUBLE PRECISION,
    "peakFee" DOUBLE PRECISION,
    "minFee" DOUBLE PRECISION,
    "txCount" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GasAnalyticsSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GasGolfingTip" (
    "id" TEXT NOT NULL,
    "functionName" TEXT NOT NULL,
    "tips" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GasGolfingTip_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GovernanceContract" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "governanceType" TEXT NOT NULL,
    "proposals" JSONB,
    "votingToken" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GovernanceContract_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GovernanceDelegate" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "delegatee" TEXT NOT NULL,
    "delegatedVotes" DOUBLE PRECISION,
    "delegators" TEXT[],
    "proposalsVoted" INTEGER,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GovernanceDelegate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GovernanceProposal" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "proposalId" TEXT NOT NULL,
    "proposer" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "targets" JSONB NOT NULL,
    "startBlock" INTEGER NOT NULL,
    "endBlock" INTEGER NOT NULL,
    "quorum" INTEGER,
    "status" TEXT NOT NULL,
    "executedAt" TIMESTAMP(3),
    "executionTxHash" TEXT,
    "votes" JSONB,
    "votesFor" DOUBLE PRECISION,
    "votesAgainst" DOUBLE PRECISION,
    "votesAbstain" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GovernanceProposal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GovernanceVote" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "proposalId" TEXT NOT NULL,
    "voter" TEXT NOT NULL,
    "weight" DOUBLE PRECISION,
    "support" BOOLEAN,
    "reason" TEXT,
    "transactionHash" TEXT,
    "ledgerSequence" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GovernanceVote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LinkedIdentity" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "chainId" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "verified" BOOLEAN NOT NULL,
    "metadata" JSONB,
    "lastVerified" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LinkedIdentity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MarketDataSnapshot" (
    "id" TEXT NOT NULL,
    "tokenAddress" TEXT NOT NULL,
    "tokenSymbol" TEXT,
    "priceUsd" DOUBLE PRECISION,
    "volume24h" DOUBLE PRECISION,
    "tvl" DOUBLE PRECISION,
    "liquidity" DOUBLE PRECISION,
    "priceChange1h" DOUBLE PRECISION,
    "priceChange24h" DOUBLE PRECISION,
    "trades24h" INTEGER,
    "uniqueTraders24h" INTEGER,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MarketDataSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NetworkNode" (
    "id" TEXT NOT NULL,
    "nodeId" TEXT NOT NULL,
    "ipAddress" TEXT,
    "port" INTEGER,
    "overlayVersion" INTEGER,
    "ledgerVersion" INTEGER,
    "isValidator" BOOLEAN NOT NULL,
    "activeInNetwork" BOOLEAN NOT NULL,
    "agreementRate24h" DOUBLE PRECISION,
    "agreementRate7d" DOUBLE PRECISION,
    "agreementRate30d" DOUBLE PRECISION,
    "country" TEXT,
    "countryCode" TEXT,
    "firstSeen" TIMESTAMP(3),
    "lastSeen" TIMESTAMP(3),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "missedSlots24h" INTEGER,
    "missedSlots7d" INTEGER,
    "name" TEXT,
    "networkProfile" TEXT,
    "nodeEvents" JSONB,
    "nodeMetrics" JSONB,
    "organization" TEXT,
    "organizationName" TEXT,
    "publicKey" TEXT,
    "quorumSet" JSONB,
    "quorumVotes" INTEGER,
    "roundTripLatencyMs" INTEGER,
    "state" TEXT,
    "stellarCoreVersion" TEXT,
    "uptime24h" DOUBLE PRECISION,
    "uptime7d" DOUBLE PRECISION,
    "uptime30d" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NetworkNode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OperationBenchmark" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "avgCpu" DOUBLE PRECISION,
    "avgMemory" DOUBLE PRECISION,
    "avgFeeStroops" DOUBLE PRECISION,
    "samples" INTEGER NOT NULL,
    "lastUpdated" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OperationBenchmark_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OracleCallback" (
    "id" TEXT NOT NULL,
    "oracleContractAddress" TEXT NOT NULL,
    "dataRequestorAddress" TEXT NOT NULL,
    "requestTimestamp" TIMESTAMP(3) NOT NULL,
    "roundTripLatencyMs" INTEGER,
    "status" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OracleCallback_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PoolSnapshot" (
    "id" TEXT NOT NULL,
    "poolAddress" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "reserveA" TEXT,
    "reserveB" TEXT,
    "tvlUsd" DOUBLE PRECISION,
    "volume24hUsd" DOUBLE PRECISION,
    "fees24hUsd" DOUBLE PRECISION,
    "aprPct" DOUBLE PRECISION,
    "priceAUsd" DOUBLE PRECISION,
    "priceBUsd" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PoolSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PoolSwap" (
    "id" TEXT NOT NULL,
    "poolAddress" TEXT NOT NULL,
    "tokenIn" TEXT NOT NULL,
    "amountIn" TEXT,
    "transactionHash" TEXT,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PoolSwap_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PortfolioSnapshot" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "assetCode" TEXT,
    "assetIssuer" TEXT,
    "estimatedVolume" DOUBLE PRECISION,
    "priceXlm" DOUBLE PRECISION,
    "priceUsd" DOUBLE PRECISION,
    "valueXlm" DOUBLE PRECISION,
    "valueUsd" DOUBLE PRECISION,
    "snapshotAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PortfolioSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrivacyAnalytics" (
    "id" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "period" TEXT,
    "totalPrivateTx" INTEGER,
    "totalTx" INTEGER,
    "totalVolume" DOUBLE PRECISION,
    "privacyShare" DOUBLE PRECISION,
    "volumeShare" DOUBLE PRECISION,
    "byProtocol" JSONB,
    "avgAnonymitySet" DOUBLE PRECISION,
    "maxAnonymitySet" INTEGER,
    "medianAnonymitySet" INTEGER,
    "avgPrivacyScore" DOUBLE PRECISION,
    "avgRiskScore" DOUBLE PRECISION,
    "uniqueUsers" INTEGER,
    "uniqueContracts" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PrivacyAnalytics_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrivacyComplianceReport" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "totalPrivateTx" INTEGER,
    "protocolsUsed" TEXT[],
    "riskScore" DOUBLE PRECISION,
    "flagged" BOOLEAN NOT NULL,
    "flagReason" TEXT,
    "complianceLabel" TEXT,
    "linkedAddresses" TEXT[],
    "lastActivity" TIMESTAMP(3) NOT NULL,
    "reportGeneratedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PrivacyComplianceReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrivacyProtocolDetail" (
    "id" TEXT NOT NULL,
    "protocol" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "period" TEXT,
    "txCount" INTEGER,
    "volume" DOUBLE PRECISION,
    "uniqueUsers" INTEGER,
    "uniqueContracts" INTEGER,
    "avgAnonymitySet" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PrivacyProtocolDetail_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrivacyTransaction" (
    "id" TEXT NOT NULL,
    "txHash" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "protocols" TEXT[],
    "guarantees" TEXT[],
    "cryptographicPrimitives" JSONB,
    "anonymitySetSize" INTEGER,
    "effectiveAnonymitySet" INTEGER,
    "privacyScore" DOUBLE PRECISION,
    "riskScore" DOUBLE PRECISION,
    "totalValue" TEXT,
    "usdValue" DOUBLE PRECISION,
    "assetType" TEXT,
    "participants" TEXT[],
    "contractAddresses" TEXT[],
    "participantCount" INTEGER,
    "ledgerSequence" INTEGER,
    "sourceAccount" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PrivacyTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReentrancyAlert" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "severity" TEXT,
    "repeatedWithdrawCalls" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReentrancyAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RegisteredDapp" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "apiKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RegisteredDapp_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationBadge" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "badgeType" TEXT NOT NULL,
    "title" TEXT,
    "description" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationBadge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationDelegation" (
    "id" TEXT NOT NULL,
    "delegator" TEXT NOT NULL,
    "delegatee" TEXT NOT NULL,
    "amount" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationDelegation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationDispute" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "challenger" TEXT NOT NULL,
    "respondent" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "challenge" TEXT,
    "evidenceHash" TEXT,
    "quorumVotes" INTEGER,
    "outcome" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReputationDispute_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationDisputeVote" (
    "id" TEXT NOT NULL,
    "disputeId" TEXT NOT NULL,
    "voter" TEXT NOT NULL,
    "vote" TEXT,
    "weight" DOUBLE PRECISION,
    "signature" TEXT,
    "transactionHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationDisputeVote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationGovernanceVote" (
    "id" TEXT NOT NULL,
    "proposalId" TEXT NOT NULL,
    "voter" TEXT NOT NULL,
    "vote" TEXT,
    "weight" DOUBLE PRECISION,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationGovernanceVote_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationNft" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "badgeType" TEXT NOT NULL,
    "tokenId" TEXT,
    "mintedTxHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationNft_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationProfile" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "chain" TEXT,
    "combinedScore" DOUBLE PRECISION,
    "sorobanScore" DOUBLE PRECISION,
    "stellarScore" DOUBLE PRECISION,
    "ethScore" DOUBLE PRECISION,
    "solScore" DOUBLE PRECISION,
    "categoryScores" JSONB,
    "signalBreakdown" JSONB,
    "categories" TEXT[],
    "badgeIds" TEXT[],
    "lastUpdated" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReputationProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationTrustConnection" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "fromAddress" TEXT,
    "toAddress" TEXT,
    "chainId" TEXT,
    "type" TEXT,
    "timestamp" TIMESTAMP(3),
    "transactionHash" TEXT,
    "weight" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationTrustConnection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReputationSignal" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "signalType" TEXT NOT NULL,
    "value" DOUBLE PRECISION,
    "weight" DOUBLE PRECISION,
    "normalizedScore" DOUBLE PRECISION,
    "chain" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReputationSignal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RwaComplianceEvent" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "assetContractAddress" TEXT NOT NULL,
    "issuerAddress" TEXT,
    "targetAddress" TEXT,
    "amount" TEXT,
    "complianceReason" TEXT,
    "humanStatement" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RwaComplianceEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxAccount" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "publicKey" TEXT,
    "balance" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SandboxAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxCall" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "contractId" TEXT,
    "functionName" TEXT NOT NULL,
    "args" JSONB,
    "results" JSONB,
    "gasUsed" INTEGER,
    "success" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SandboxCall_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxCiRun" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "passed" INTEGER,
    "failed" INTEGER,
    "totalTests" INTEGER,
    "logs" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SandboxCiRun_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxContract" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "contractId" TEXT,
    "name" TEXT,
    "state" JSONB,
    "abi" JSONB,
    "source" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SandboxContract_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "state" TEXT,
    "context" JSONB,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SandboxSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxShare" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "shareId" TEXT NOT NULL,
    "viewOnly" BOOLEAN,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SandboxShare_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SandboxSnapshot" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "label" TEXT,
    "state" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SandboxSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SettlementBatchSummary" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "ledgerMin" INTEGER NOT NULL,
    "ledgerMax" INTEGER NOT NULL,
    "txCount" INTEGER NOT NULL,
    "totalAmount" TEXT,
    "batchId" TEXT NOT NULL,
    "windowKey" TEXT,
    "eventCount" INTEGER,
    "compacted" BOOLEAN,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SettlementBatchSummary_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShieldedTransfer" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "fromAddress" TEXT NOT NULL,
    "toAddress" TEXT NOT NULL,
    "amount" TEXT,
    "isConfidential" BOOLEAN NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShieldedTransfer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SignatureInspection" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "curveType" TEXT,
    "isPasskey" BOOLEAN,
    "pubKeyX" TEXT,
    "pubKeyY" TEXT,
    "label" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SignatureInspection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SignerSnapshot" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "signers" JSONB,
    "highThreshold" INTEGER,
    "ledgerSequence" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SignerSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StandardCompliance" (
    "id" TEXT NOT NULL,
    "contractType" TEXT NOT NULL,
    "functionName" TEXT NOT NULL,
    "maxFeeStroops" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StandardCompliance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StateContention" (
    "id" TEXT NOT NULL,
    "ledgerSequence" INTEGER NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "stateKey" TEXT,
    "txHashes" TEXT[],
    "conflictCount" INTEGER,
    "delayMs" INTEGER,
    "delayLabel" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StateContention_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ThreatAdvisory" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "severity" TEXT NOT NULL,
    "cvssScore" DOUBLE PRECISION,
    "cveId" TEXT,
    "ghsaId" TEXT,
    "affectedContracts" TEXT[],
    "affectedChains" TEXT[],
    "mitigations" TEXT,
    "tags" TEXT[],
    "sourceId" TEXT,
    "status" TEXT NOT NULL,
    "publishedAt" TIMESTAMP(3),
    "externalUrl" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ThreatAdvisory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ThreatComment" (
    "id" TEXT NOT NULL,
    "advisoryId" TEXT NOT NULL,
    "authorKey" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ThreatComment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ThreatReview" (
    "id" TEXT NOT NULL,
    "advisoryId" TEXT NOT NULL,
    "role" TEXT,
    "decision" TEXT,
    "notes" TEXT,
    "reviewerKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ThreatReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TipSubscription" (
    "id" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL,
    "filters" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TipSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TipWebhook" (
    "id" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "events" JSONB,
    "secret" TEXT,
    "active" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TipWebhook_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Token" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "name" TEXT,
    "symbol" TEXT,
    "decimals" INTEGER,
    "totalSupply" TEXT,
    "contractAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Token_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TokenPrice" (
    "id" TEXT NOT NULL,
    "tokenAddress" TEXT NOT NULL,
    "priceUsd" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "priceXlm" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "source" TEXT NOT NULL DEFAULT 'composite',
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "volume24hUsd" DECIMAL(65,30),
    "volume24hXlm" DECIMAL(65,30),
    "marketCapUsd" DECIMAL(65,30),
    "fullyDilutedValuation" DECIMAL(65,30),
    "circulatingSupply" DECIMAL(65,30),
    "totalSupply" DECIMAL(65,30),
    "priceChange1h" DOUBLE PRECISION,
    "priceChange24h" DOUBLE PRECISION,
    "priceChange7d" DOUBLE PRECISION,
    "twap1h" DECIMAL(65,30),
    "twap24h" DECIMAL(65,30),
    "liquidityUsd" DECIMAL(65,30),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TokenPrice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TokenPriceHistory" (
    "id" TEXT NOT NULL,
    "tokenAddress" TEXT NOT NULL,
    "priceUsd" DECIMAL(65,30) NOT NULL,
    "priceXlm" DECIMAL(65,30) NOT NULL,
    "source" TEXT NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL,
    "volume24hUsd" DECIMAL(65,30),
    "marketCapUsd" DECIMAL(65,30),
    "timestamp" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TokenPriceHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TokenMarketData" (
    "id" TEXT NOT NULL,
    "tokenAddress" TEXT NOT NULL,
    "symbol" TEXT,
    "name" TEXT,
    "decimals" INTEGER,
    "totalSupply" DECIMAL(65,30),
    "circulatingSupply" DECIMAL(65,30),
    "holderCount" INTEGER NOT NULL DEFAULT 0,
    "transferCount24h" INTEGER NOT NULL DEFAULT 0,
    "uniqueSenders24h" INTEGER NOT NULL DEFAULT 0,
    "uniqueReceivers24h" INTEGER NOT NULL DEFAULT 0,
    "averageTransferValueUsd" DECIMAL(65,30),
    "isStablecoin" BOOLEAN NOT NULL DEFAULT false,
    "stablecoinPeg" TEXT,
    "pegDeviation24h" DOUBLE PRECISION,
    "pegStabilityScore" DOUBLE PRECISION,
    "tags" TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TokenMarketData_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PriceAlert" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "tokenAddress" TEXT NOT NULL,
    "alertType" TEXT NOT NULL,
    "threshold" TEXT NOT NULL,
    "timeWindow" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "lastTriggeredAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PriceAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VerifiableCredential" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "credentialId" TEXT NOT NULL,
    "context" TEXT,
    "type" TEXT,
    "issuer" TEXT,
    "issuanceDate" TIMESTAMP(3),
    "expirationDate" TIMESTAMP(3),
    "subjectId" TEXT,
    "subjectData" JSONB,
    "proofType" TEXT,
    "proofCreated" TIMESTAMP(3),
    "verificationMethod" TEXT,
    "proofPurpose" TEXT,
    "proofValue" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VerifiableCredential_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VolumeAlert" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "acknowledged" BOOLEAN NOT NULL,
    "baseline" DOUBLE PRECISION,
    "currentCount" INTEGER,
    "detectedAt" TIMESTAMP(3) NOT NULL,
    "severity" TEXT,
    "stdDev" DOUBLE PRECISION,
    "message" TEXT,
    "windowMinutes" INTEGER,
    "zScore" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VolumeAlert_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VulnerabilitySource" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "sourceType" TEXT NOT NULL,
    "feedUrl" TEXT,
    "lastFetchAt" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VulnerabilitySource_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WebhookDelivery" (
    "id" TEXT NOT NULL,
    "subscriptionId" TEXT NOT NULL,
    "eventId" TEXT,
    "attempt" INTEGER,
    "status" TEXT,
    "processingStatus" TEXT NOT NULL DEFAULT 'idle',
    "leaseExpiresAt" TIMESTAMP(3),
    "httpStatus" INTEGER,
    "responseBody" TEXT,
    "errorMsg" TEXT,
    "deliveredAt" TIMESTAMP(3),
    "nextRetryAt" TIMESTAMP(3),
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WebhookDelivery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WebhookSubscription" (
    "id" TEXT NOT NULL,
    "apiKeyId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "secret" TEXT NOT NULL,
    "contractAddress" TEXT,
    "eventType" TEXT,
    "topicSymbol" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "storeResponseBody" BOOLEAN NOT NULL DEFAULT true,
    "responseRetentionDays" INTEGER NOT NULL DEFAULT 90,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WebhookSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "YieldDistribution" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "distributionId" TEXT NOT NULL,
    "recipient" TEXT NOT NULL,
    "amount" TEXT,
    "tokenSymbol" TEXT,
    "windowLabel" TEXT,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "YieldDistribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "YieldHistorySnapshot" (
    "id" TEXT NOT NULL,
    "opportunityId" TEXT NOT NULL,
    "snapshotDate" TIMESTAMP(3) NOT NULL,
    "apy" DOUBLE PRECISION,
    "baseApy" DOUBLE PRECISION,
    "incentiveApy" DOUBLE PRECISION,
    "tvl" DOUBLE PRECISION,
    "ledgerSequence" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "YieldHistorySnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "YieldOpportunity" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "tokens" TEXT[],
    "baseApy" DOUBLE PRECISION,
    "incentiveApy" DOUBLE PRECISION,
    "totalApy" DOUBLE PRECISION,
    "tvl" DOUBLE PRECISION,
    "lockupDays" INTEGER,
    "minDeposit" TEXT,
    "depositFee" DOUBLE PRECISION,
    "withdrawFee" DOUBLE PRECISION,
    "riskScore" DOUBLE PRECISION,
    "riskLabel" TEXT,
    "lastObservedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "YieldOpportunity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ZkpVerificationEvent" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "proofType" TEXT,
    "publicInputHash" TEXT,
    "verificationResult" BOOLEAN,
    "certaintyPercent" DOUBLE PRECISION,
    "ledgerSequence" INTEGER NOT NULL,
    "ledgerCloseTime" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ZkpVerificationEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "call_graph_vertices" (
    "id" TEXT NOT NULL,
    "tx_hash" TEXT NOT NULL,
    "contract_address" TEXT NOT NULL,
    "function_name" TEXT NOT NULL,
    "depth" INTEGER NOT NULL,
    "call_index" INTEGER NOT NULL,
    "value" TEXT,
    "pre_state_reads" JSONB,
    "post_state_writes" JSONB,
    "timestamp" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "call_graph_vertices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "call_graph_edges" (
    "id" TEXT NOT NULL,
    "tx_hash" TEXT NOT NULL,
    "from_vertex_id" TEXT NOT NULL,
    "to_vertex_id" TEXT NOT NULL,
    "function_name" TEXT NOT NULL,
    "value" TEXT,
    "gas_forwarded" INTEGER,
    "args_hash" TEXT,
    "call_index" INTEGER NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "call_graph_edges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reentrancy_findings" (
    "id" TEXT NOT NULL,
    "tx_hash" TEXT NOT NULL,
    "contract_address" TEXT NOT NULL,
    "reentrancy_type" "ReentrancyType" NOT NULL,
    "severity" "ReentrancySeverity" NOT NULL,
    "likelihood" TEXT NOT NULL,
    "loopPath" JSONB NOT NULL,
    "entry_point" TEXT NOT NULL,
    "value_at_risk" TEXT,
    "usd_value_at_risk" DOUBLE PRECISION,
    "profit_potential" DOUBLE PRECISION,
    "description" TEXT NOT NULL,
    "detected_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "reentrancy_findings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "contract_risk_scores" (
    "id" TEXT NOT NULL,
    "contract_address" TEXT NOT NULL,
    "risk_score" INTEGER NOT NULL,
    "previous_score" INTEGER,
    "total_findings" INTEGER NOT NULL,
    "critical_findings" INTEGER NOT NULL,
    "high_findings" INTEGER NOT NULL,
    "medium_findings" INTEGER NOT NULL,
    "risk_factors" JSONB NOT NULL,
    "last_analyzed" TIMESTAMP(3) NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "contract_risk_scores_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reentrancy_alerts" (
    "id" TEXT NOT NULL,
    "contract_address" TEXT NOT NULL,
    "finding_id" TEXT,
    "alert_type" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL,
    "acknowledged" BOOLEAN NOT NULL DEFAULT false,
    "acknowledged_at" TIMESTAMP(3),

    CONSTRAINT "reentrancy_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reentrancy_stats" (
    "id" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "total_call_graphs" INTEGER NOT NULL,
    "contracts_analyzed" INTEGER NOT NULL,
    "contracts_with_loops" INTEGER NOT NULL,
    "high_risk_contracts" INTEGER NOT NULL,
    "critical_findings" INTEGER NOT NULL,
    "total_findings" INTEGER NOT NULL,
    "most_common_patterns" JSONB NOT NULL,
    "avg_depth" DOUBLE PRECISION,
    "max_depth" INTEGER,
    "value_at_risk_total" TEXT,

    CONSTRAINT "reentrancy_stats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_queries" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "query" TEXT NOT NULL,
    "language" TEXT,
    "interpretedQuery" JSONB,
    "sql" TEXT,
    "apiEndpoint" TEXT,
    "resolved" BOOLEAN NOT NULL DEFAULT false,
    "responseTime" INTEGER,
    "tokensUsed" INTEGER,
    "feedback" "QueryFeedback",
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nl_queries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_query_contexts" (
    "id" TEXT NOT NULL,
    "query_id" TEXT NOT NULL,
    "session_id" TEXT,
    "previous_queries" JSONB,
    "resolved_entities" JSONB,
    "active_filters" JSONB,
    "context_window" INTEGER NOT NULL DEFAULT 5,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nl_query_contexts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_sessions" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "context" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "nl_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "saved_queries" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "name" TEXT NOT NULL,
    "nl_template" TEXT NOT NULL,
    "parameters" JSONB,
    "schedule" TEXT,
    "last_run" TIMESTAMP(3),
    "next_run" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "query_id" TEXT,

    CONSTRAINT "saved_queries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_embeddings" (
    "id" TEXT NOT NULL,
    "query" TEXT NOT NULL,
    "embedding" BYTEA NOT NULL,
    "intent" TEXT NOT NULL,
    "filters" JSONB,
    "usage_count" INTEGER NOT NULL DEFAULT 0,
    "success_rate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "nl_embeddings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_query_templates" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "nl_template" TEXT NOT NULL,
    "parameters" JSONB,
    "category" TEXT,
    "usage_count" INTEGER NOT NULL DEFAULT 0,
    "is_public" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "nl_query_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_reports" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "name" TEXT NOT NULL,
    "nl_template" TEXT NOT NULL,
    "parameters" JSONB,
    "schedule" TEXT,
    "report_type" TEXT NOT NULL DEFAULT 'one-time',
    "webhook_url" TEXT,
    "email" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "last_run" TIMESTAMP(3),
    "next_run" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "nl_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_report_history" (
    "id" TEXT NOT NULL,
    "report_id" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "result" JSONB,
    "error" TEXT,
    "ran_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nl_report_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nl_alerts" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "nl_query" TEXT NOT NULL,
    "intent" TEXT NOT NULL,
    "conditions" JSONB,
    "webhook_url" TEXT,
    "email" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "last_fired" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "nl_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "archival_nodes" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "name" TEXT,
    "endpoint" TEXT NOT NULL,
    "stakedAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "stakeAsset" TEXT NOT NULL DEFAULT 'XLM',
    "commission" DOUBLE PRECISION,
    "reputation" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "reputationHistory" JSONB,
    "totalEarnings" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalServed" INTEGER NOT NULL DEFAULT 0,
    "totalChallenges" INTEGER NOT NULL DEFAULT 0,
    "challengesPassed" INTEGER NOT NULL DEFAULT 0,
    "challengesFailed" INTEGER NOT NULL DEFAULT 0,
    "uptime24h" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "uptime7d" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "uptime30d" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "avgResponseTime" INTEGER,
    "p95ResponseTime" INTEGER,
    "maxStorageGb" INTEGER,
    "usedStorageGb" INTEGER,
    "supportedEpochs" JSONB,
    "slashedAmount" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" "ArchivalNodeStatus" NOT NULL DEFAULT 'active',
    "registeredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeen" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "archival_nodes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "archival_epochs" (
    "id" TEXT NOT NULL,
    "epochId" INTEGER NOT NULL,
    "startLedger" INTEGER NOT NULL,
    "endLedger" INTEGER NOT NULL,
    "sizeBytes" BIGINT,
    "checksum" TEXT,
    "merkleRoot" TEXT,
    "nodeId" TEXT NOT NULL,
    "status" "EpochStatus" NOT NULL DEFAULT 'stored',
    "verifiedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "archival_epochs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "storage_challenges" (
    "id" TEXT NOT NULL,
    "epochId" TEXT NOT NULL,
    "nodeId" TEXT NOT NULL,
    "challengeType" TEXT NOT NULL,
    "challengeData" JSONB,
    "responseData" JSONB,
    "status" "ChallengeStatus" NOT NULL DEFAULT 'pending',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "proofVerified" BOOLEAN,
    "slashed" BOOLEAN NOT NULL DEFAULT false,
    "issuedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),
    "verifiedAt" TIMESTAMP(3),

    CONSTRAINT "storage_challenges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "data_retrievals" (
    "id" TEXT NOT NULL,
    "requester" TEXT NOT NULL,
    "epochId" TEXT,
    "nodeId" TEXT,
    "ledgerRange" JSONB,
    "contractId" TEXT,
    "fee" DOUBLE PRECISION NOT NULL,
    "feeAsset" TEXT NOT NULL,
    "status" "RetrievalStatus" NOT NULL,
    "responseSize" INTEGER,
    "responseTime" INTEGER,
    "error" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "data_retrievals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sla_offers" (
    "id" TEXT NOT NULL,
    "nodeId" TEXT NOT NULL,
    "tier" TEXT NOT NULL,
    "uptime" DOUBLE PRECISION NOT NULL,
    "responseMs" INTEGER NOT NULL,
    "description" TEXT,
    "pricePerGb" DOUBLE PRECISION NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sla_offers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sla_acceptances" (
    "id" TEXT NOT NULL,
    "offerId" TEXT NOT NULL,
    "requester" TEXT NOT NULL,
    "fee" DOUBLE PRECISION NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sla_acceptances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "archival_slashes" (
    "id" TEXT NOT NULL,
    "nodeId" TEXT NOT NULL,
    "challengeId" TEXT,
    "amount" DOUBLE PRECISION NOT NULL,
    "reason" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "archival_slashes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "archival_appeals" (
    "id" TEXT NOT NULL,
    "slashId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "evidence" JSONB,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "decision" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "archival_appeals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftCollection" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "name" TEXT,
    "symbol" TEXT,
    "description" TEXT,
    "category" TEXT,
    "totalSupply" INTEGER NOT NULL DEFAULT 0,
    "uniqueHolders" INTEGER NOT NULL DEFAULT 0,
    "floorPrice" DECIMAL(65,30),
    "floorPriceToken" TEXT,
    "floorPriceUsd" DECIMAL(65,30),
    "totalVolume" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "volume24h" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "volume7d" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "volume30d" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "avgPrice24h" DECIMAL(65,30),
    "avgPrice7d" DECIMAL(65,30),
    "marketCap" DECIMAL(65,30),
    "mintPrice" DECIMAL(65,30),
    "mintStart" TIMESTAMP(3),
    "mintEnd" TIMESTAMP(3),
    "royaltyPct" DOUBLE PRECISION,
    "royaltyRecipient" TEXT,
    "website" TEXT,
    "discord" TEXT,
    "twitter" TEXT,
    "logoUri" TEXT,
    "bannerUri" TEXT,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "isSpam" BOOLEAN NOT NULL DEFAULT false,
    "isMintable" BOOLEAN NOT NULL DEFAULT false,
    "detectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "lastSaleAt" TIMESTAMP(3),

    CONSTRAINT "NftCollection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftItem" (
    "id" TEXT NOT NULL,
    "collectionId" TEXT NOT NULL,
    "tokenId" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "mintedAt" TIMESTAMP(3) NOT NULL,
    "mintTxHash" TEXT NOT NULL,
    "mintPrice" DECIMAL(65,30),
    "lastSalePrice" DECIMAL(65,30),
    "lastSalePriceUsd" DECIMAL(65,30),
    "lastSaleAt" TIMESTAMP(3),
    "saleCount" INTEGER NOT NULL DEFAULT 0,
    "metadata" JSONB,
    "metadataUri" TEXT,
    "metadataFetchedAt" TIMESTAMP(3),
    "rarityScore" DOUBLE PRECISION,
    "rarityRank" INTEGER,
    "isListed" BOOLEAN NOT NULL DEFAULT false,
    "listingPrice" DECIMAL(65,30),
    "listingMarket" TEXT,
    "isSoulbound" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NftItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftTrait" (
    "id" TEXT NOT NULL,
    "collectionId" TEXT NOT NULL,
    "traitType" TEXT NOT NULL,
    "traitValue" TEXT NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "rarityScore" DOUBLE PRECISION,
    "rarityTier" TEXT,

    CONSTRAINT "NftTrait_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftSale" (
    "id" TEXT NOT NULL,
    "collectionId" TEXT NOT NULL,
    "itemId" TEXT,
    "tokenId" TEXT NOT NULL,
    "seller" TEXT NOT NULL,
    "buyer" TEXT NOT NULL,
    "price" DECIMAL(65,30) NOT NULL,
    "priceUsd" DECIMAL(65,30),
    "priceToken" TEXT,
    "txHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER,
    "marketplace" TEXT,
    "saleType" TEXT NOT NULL,
    "saleAt" TIMESTAMP(3) NOT NULL,
    "indexedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "isWashTrade" BOOLEAN NOT NULL DEFAULT false,
    "washTradeScore" DOUBLE PRECISION,

    CONSTRAINT "NftSale_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftListing" (
    "id" TEXT NOT NULL,
    "collectionId" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "tokenId" TEXT NOT NULL,
    "seller" TEXT NOT NULL,
    "price" DECIMAL(65,30) NOT NULL,
    "priceUsd" DECIMAL(65,30),
    "priceToken" TEXT,
    "marketplace" TEXT,
    "listedAt" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3),
    "status" TEXT NOT NULL,
    "cancelledAt" TIMESTAMP(3),

    CONSTRAINT "NftListing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftCollectionStats" (
    "id" TEXT NOT NULL,
    "collectionId" TEXT NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "floorPrice" DECIMAL(65,30),
    "floorPriceUsd" DECIMAL(65,30),
    "totalVolume" DECIMAL(65,30) NOT NULL,
    "volume24h" DECIMAL(65,30) NOT NULL,
    "avgPrice24h" DECIMAL(65,30),
    "uniqueHolders" INTEGER NOT NULL,
    "totalSupply" INTEGER NOT NULL,
    "washVolume24h" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "washTxCount24h" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "NftCollectionStats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftPortfolio" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "owner" TEXT NOT NULL,
    "name" TEXT,
    "items" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "totalValueUsd" DECIMAL(65,30),
    "totalPaidUsd" DECIMAL(65,30),
    "unrealizedPnlUsd" DECIMAL(65,30),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NftPortfolio_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftActivity" (
    "id" TEXT NOT NULL,
    "collectionId" TEXT NOT NULL,
    "itemId" TEXT,
    "tokenId" TEXT NOT NULL,
    "activityType" TEXT NOT NULL,
    "fromAddress" TEXT,
    "toAddress" TEXT,
    "price" DECIMAL(65,30),
    "priceUsd" DECIMAL(65,30),
    "txHash" TEXT NOT NULL,
    "ledgerSequence" INTEGER,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "metadata" JSONB,

    CONSTRAINT "NftActivity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NftMarketplace" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "name" TEXT,
    "description" TEXT,
    "website" TEXT,
    "logoUri" TEXT,
    "totalVolume" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "volume24h" DECIMAL(65,30) NOT NULL DEFAULT 0,
    "totalListings" INTEGER NOT NULL DEFAULT 0,
    "activeListings" INTEGER NOT NULL DEFAULT 0,
    "uniqueCollections" INTEGER NOT NULL DEFAULT 0,
    "activeTraders24h" INTEGER NOT NULL DEFAULT 0,
    "feePct" DOUBLE PRECISION,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "detectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NftMarketplace_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ApiAuditLog" (
    "id" TEXT NOT NULL,
    "apiKeyId" TEXT,
    "keyName" TEXT,
    "tier" TEXT NOT NULL DEFAULT 'unauthenticated',
    "ip" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "endpoint" TEXT NOT NULL,
    "statusCode" INTEGER NOT NULL,
    "responseTimeMs" INTEGER NOT NULL DEFAULT 0,
    "rateLimitRemaining" INTEGER,
    "rateLimitLimit" INTEGER,
    "userAgent" TEXT,
    "requestId" TEXT,
    "region" TEXT,
    "isRateLimited" BOOLEAN NOT NULL DEFAULT false,
    "month" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ApiAuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AbuseEvent" (
    "id" TEXT NOT NULL,
    "pattern" TEXT NOT NULL,
    "ip" TEXT,
    "apiKeyId" TEXT,
    "endpoint" TEXT,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "action" TEXT NOT NULL DEFAULT 'monitor',
    "blockedUntil" TIMESTAMP(3),
    "evidence" JSONB,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AbuseEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bridge_transactions" (
    "id" TEXT NOT NULL,
    "transactionHash" TEXT NOT NULL,
    "sourceChain" VARCHAR(50) NOT NULL,
    "destinationChain" VARCHAR(50) NOT NULL,
    "asset" VARCHAR(50) NOT NULL,
    "amount" DECIMAL(30,7) NOT NULL,
    "sender" VARCHAR(100) NOT NULL,
    "recipient" VARCHAR(100) NOT NULL,
    "protocol" VARCHAR(50) NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
    "confirmations" INTEGER NOT NULL DEFAULT 0,
    "requiredConfirmations" INTEGER NOT NULL DEFAULT 0,
    "sourceTimestamp" TIMESTAMP(3),
    "destinationTimestamp" TIMESTAMP(3),
    "estimatedArrivalAt" TIMESTAMP(3),
    "bridgeFee" DECIMAL(20,7),
    "sourceTxUrl" TEXT,
    "destinationTxUrl" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bridge_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bridge_alerts" (
    "id" TEXT NOT NULL,
    "type" VARCHAR(50) NOT NULL,
    "severity" VARCHAR(20) NOT NULL DEFAULT 'info',
    "protocol" VARCHAR(50),
    "chain" VARCHAR(50),
    "address" VARCHAR(100),
    "transactionHash" VARCHAR(100),
    "asset" VARCHAR(50),
    "amount" DECIMAL(30,7),
    "message" TEXT NOT NULL,
    "data" JSONB,
    "acknowledged" BOOLEAN NOT NULL DEFAULT false,
    "triggeredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bridge_alerts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "monitored_addresses" (
    "id" TEXT NOT NULL,
    "address" VARCHAR(100) NOT NULL,
    "chain" VARCHAR(50) NOT NULL,
    "label" TEXT,
    "minAlertUsd" DECIMAL(20,2),
    "alertOnTx" BOOLEAN NOT NULL DEFAULT true,
    "alertOnBridging" BOOLEAN NOT NULL DEFAULT true,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "monitored_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bridge_volumes" (
    "id" TEXT NOT NULL,
    "protocol" VARCHAR(50) NOT NULL,
    "chain" VARCHAR(50) NOT NULL,
    "asset" VARCHAR(50) NOT NULL,
    "volume" DECIMAL(30,7) NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "period" VARCHAR(20) NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bridge_volumes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallet_users" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'user',
    "tier" TEXT NOT NULL DEFAULT 'free',
    "displayName" TEXT,
    "email" TEXT,
    "avatarUrl" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isMultiSig" BOOLEAN NOT NULL DEFAULT false,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "lastLogin" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wallet_users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_sessions" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "refreshTokenHash" TEXT NOT NULL,
    "deviceInfo" JSONB,
    "appId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "revokedAt" TIMESTAMP(3),
    "revocationReason" TEXT,
    "lastActivity" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_events" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "sessionId" TEXT,
    "eventType" TEXT NOT NULL,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_webhooks" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "events" JSONB NOT NULL,
    "secret" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_webhooks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "multisig_wallets" (
    "id" TEXT NOT NULL,
    "walletAddress" TEXT NOT NULL,
    "signers" JSONB NOT NULL,
    "threshold" INTEGER NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "multisig_wallets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oauth_apps" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "clientSecret" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "redirectUris" JSONB NOT NULL,
    "scopes" JSONB NOT NULL,
    "ownerId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "oauth_apps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "oauth_codes" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "redirectUri" TEXT NOT NULL,
    "scopes" JSONB NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "oauth_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wasm_abi_extracts" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "functions" JSONB NOT NULL,
    "exports" JSONB NOT NULL,
    "imports" JSONB NOT NULL,
    "sepStandards" TEXT[],
    "coverageScore" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "warnings" TEXT[],
    "wasmHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wasm_abi_extracts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "abi_coverage_reports" (
    "id" TEXT NOT NULL,
    "contractAddress" TEXT NOT NULL,
    "totalCalls" INTEGER NOT NULL,
    "matchedCalls" INTEGER NOT NULL,
    "coveragePercent" DOUBLE PRECISION NOT NULL,
    "falsePositives" TEXT[],
    "falseNegatives" TEXT[],
    "confidenceByFunction" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "abi_coverage_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "abi_community_contributions" (
    "id" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "functionName" TEXT NOT NULL,
    "params" JSONB NOT NULL,
    "returns" TEXT NOT NULL,
    "contributor" TEXT,
    "approved" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "abi_community_contributions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Ledger_hash_key" ON "Ledger"("hash");

-- CreateIndex
CREATE INDEX "Ledger_sequence_idx" ON "Ledger"("sequence");

-- CreateIndex
CREATE INDEX "Ledger_closeTime_idx" ON "Ledger"("closeTime");

-- CreateIndex
CREATE UNIQUE INDEX "Contract_address_key" ON "Contract"("address");

-- CreateIndex
CREATE INDEX "Contract_address_idx" ON "Contract"("address");

-- CreateIndex
CREATE INDEX "WasmUpgradeHistory_contractAddress_ledgerSequence_idx" ON "WasmUpgradeHistory"("contractAddress", "ledgerSequence");

-- CreateIndex
CREATE INDEX "WasmUpgradeHistory_ledgerSequence_idx" ON "WasmUpgradeHistory"("ledgerSequence");

-- CreateIndex
CREATE INDEX "WasmUpgradeHistory_isSuspicious_idx" ON "WasmUpgradeHistory"("isSuspicious");

-- CreateIndex
CREATE INDEX "WasmUpgradeHistory_changeClassification_idx" ON "WasmUpgradeHistory"("changeClassification");

-- CreateIndex
CREATE UNIQUE INDEX "Transaction_hash_key" ON "Transaction"("hash");

-- CreateIndex
CREATE INDEX "Transaction_hash_idx" ON "Transaction"("hash");

-- CreateIndex
CREATE INDEX "Transaction_ledgerSequence_idx" ON "Transaction"("ledgerSequence");

-- CreateIndex
CREATE INDEX "Transaction_sourceAccount_idx" ON "Transaction"("sourceAccount");

-- CreateIndex
CREATE INDEX "Transaction_contractAddress_idx" ON "Transaction"("contractAddress");

-- CreateIndex
CREATE INDEX "Transaction_status_idx" ON "Transaction"("status");

-- CreateIndex
CREATE INDEX "Transaction_contractAddress_ledgerSequence_id_idx" ON "Transaction"("contractAddress", "ledgerSequence", "id");

-- CreateIndex
CREATE INDEX "Transaction_sourceAccount_ledgerSequence_id_idx" ON "Transaction"("sourceAccount", "ledgerSequence", "id");

-- CreateIndex
CREATE INDEX "Transaction_status_ledgerSequence_id_idx" ON "Transaction"("status", "ledgerSequence", "id");

-- CreateIndex
CREATE INDEX "Transaction_ledgerSequence_id_idx" ON "Transaction"("ledgerSequence", "id");

-- CreateIndex
CREATE INDEX "Event_transactionHash_idx" ON "Event"("transactionHash");

-- CreateIndex
CREATE INDEX "Event_contractAddress_idx" ON "Event"("contractAddress");

-- CreateIndex
CREATE INDEX "Event_eventType_idx" ON "Event"("eventType");

-- CreateIndex
CREATE INDEX "Event_topicSymbol_idx" ON "Event"("topicSymbol");

-- CreateIndex
CREATE INDEX "Event_ledgerSequence_idx" ON "Event"("ledgerSequence");

-- CreateIndex
CREATE INDEX "Event_contractAddress_topicSymbol_idx" ON "Event"("contractAddress", "topicSymbol");

-- CreateIndex
CREATE INDEX "Event_contractAddress_ledgerSequence_id_idx" ON "Event"("contractAddress", "ledgerSequence", "id");

-- CreateIndex
CREATE INDEX "Event_contractAddress_eventType_ledgerSequence_idx" ON "Event"("contractAddress", "eventType", "ledgerSequence");

-- CreateIndex
CREATE INDEX "EventDefinition_contractAddress_idx" ON "EventDefinition"("contractAddress");

-- CreateIndex
CREATE UNIQUE INDEX "EventDefinition_contractAddress_topicSymbol_key" ON "EventDefinition"("contractAddress", "topicSymbol");

-- CreateIndex
CREATE UNIQUE INDEX "SessionAuthorization_eventId_key" ON "SessionAuthorization"("eventId");

-- CreateIndex
CREATE INDEX "SessionAuthorization_contractAddress_idx" ON "SessionAuthorization"("contractAddress");

-- CreateIndex
CREATE INDEX "SessionAuthorization_expiryLedger_idx" ON "SessionAuthorization"("expiryLedger");

-- CreateIndex
CREATE UNIQUE INDEX "RateLimitOverride_identifier_endpoint_key" ON "RateLimitOverride"("identifier", "endpoint");

-- CreateIndex
CREATE UNIQUE INDEX "SacMapping_sacAddress_key" ON "SacMapping"("sacAddress");

-- CreateIndex
CREATE INDEX "SacMapping_sacAddress_idx" ON "SacMapping"("sacAddress");

-- CreateIndex
CREATE INDEX "SacMapping_assetCode_idx" ON "SacMapping"("assetCode");

-- CreateIndex
CREATE UNIQUE INDEX "SacMapping_assetCode_assetIssuer_key" ON "SacMapping"("assetCode", "assetIssuer");

-- CreateIndex
CREATE INDEX "SacTrustlineMapping_gAccount_idx" ON "SacTrustlineMapping"("gAccount");

-- CreateIndex
CREATE INDEX "SacTrustlineMapping_sacAddress_idx" ON "SacTrustlineMapping"("sacAddress");

-- CreateIndex
CREATE INDEX "SacTrustlineMapping_assetCode_idx" ON "SacTrustlineMapping"("assetCode");

-- CreateIndex
CREATE INDEX "SacTrustlineMapping_status_idx" ON "SacTrustlineMapping"("status");

-- CreateIndex
CREATE INDEX "SacTrustlineMapping_ledgerSequence_idx" ON "SacTrustlineMapping"("ledgerSequence");

-- CreateIndex
CREATE INDEX "SacTrustlineMapping_changeTrustOpLedger_idx" ON "SacTrustlineMapping"("changeTrustOpLedger");

-- CreateIndex
CREATE UNIQUE INDEX "SacTrustlineMapping_gAccount_sacAddress_key" ON "SacTrustlineMapping"("gAccount", "sacAddress");

-- CreateIndex
CREATE INDEX "VerificationJob_contractAddress_idx" ON "VerificationJob"("contractAddress");

-- CreateIndex
CREATE INDEX "VerificationJob_status_idx" ON "VerificationJob"("status");

-- CreateIndex
CREATE INDEX "ContractState_contractAddress_idx" ON "ContractState"("contractAddress");

-- CreateIndex
CREATE INDEX "ContractState_status_idx" ON "ContractState"("status");

-- CreateIndex
CREATE INDEX "ContractState_liveUntilLedgerSeq_idx" ON "ContractState"("liveUntilLedgerSeq");

-- CreateIndex
CREATE UNIQUE INDEX "ContractState_contractAddress_ledgerKey_key" ON "ContractState"("contractAddress", "ledgerKey");

-- CreateIndex
CREATE UNIQUE INDEX "RestorationLog_transactionHash_key" ON "RestorationLog"("transactionHash");

-- CreateIndex
CREATE INDEX "RestorationLog_sourceAccount_idx" ON "RestorationLog"("sourceAccount");

-- CreateIndex
CREATE INDEX "RestorationLog_ledgerSequence_idx" ON "RestorationLog"("ledgerSequence");

-- CreateIndex
CREATE INDEX "FailedItem_itemType_dead_idx" ON "FailedItem"("itemType", "dead");

-- CreateIndex
CREATE INDEX "FailedItem_ledger_idx" ON "FailedItem"("ledger");

-- CreateIndex
CREATE UNIQUE INDEX "ApiKey_key_key" ON "ApiKey"("key");

-- CreateIndex
CREATE UNIQUE INDEX "SmartWallet_address_key" ON "SmartWallet"("address");

-- CreateIndex
CREATE INDEX "SmartWallet_walletType_idx" ON "SmartWallet"("walletType");

-- CreateIndex
CREATE INDEX "SmartWallet_firstSeenLedger_idx" ON "SmartWallet"("firstSeenLedger");

-- CreateIndex
CREATE INDEX "SmartWallet_deployedByAccount_idx" ON "SmartWallet"("deployedByAccount");

-- CreateIndex
CREATE UNIQUE INDEX "SponsoredTransaction_transactionHash_key" ON "SponsoredTransaction"("transactionHash");

-- CreateIndex
CREATE INDEX "SponsoredTransaction_sponsorAccount_idx" ON "SponsoredTransaction"("sponsorAccount");

-- CreateIndex
CREATE INDEX "SponsoredTransaction_sourceAccount_idx" ON "SponsoredTransaction"("sourceAccount");

-- CreateIndex
CREATE INDEX "SponsoredTransaction_walletAddress_idx" ON "SponsoredTransaction"("walletAddress");

-- CreateIndex
CREATE INDEX "SponsoredTransaction_ledgerSequence_idx" ON "SponsoredTransaction"("ledgerSequence");

-- CreateIndex
CREATE UNIQUE INDEX "AuthDecomposition_transactionHash_key" ON "AuthDecomposition"("transactionHash");

-- CreateIndex
CREATE INDEX "AuthDecomposition_walletAddress_idx" ON "AuthDecomposition"("walletAddress");

-- CreateIndex
CREATE INDEX "AuthDecomposition_ledgerSequence_idx" ON "AuthDecomposition"("ledgerSequence");

-- CreateIndex
CREATE INDEX "AuthDecomposition_ledgerSequence_id_idx" ON "AuthDecomposition"("ledgerSequence", "id");

-- CreateIndex
CREATE INDEX "SanctionsList_address_idx" ON "SanctionsList"("address");

-- CreateIndex
CREATE INDEX "SanctionsList_source_listVersion_idx" ON "SanctionsList"("source", "listVersion");

-- CreateIndex
CREATE INDEX "SanctionsList_isActive_idx" ON "SanctionsList"("isActive");

-- CreateIndex
CREATE INDEX "SanctionsList_source_isActive_idx" ON "SanctionsList"("source", "isActive");

-- CreateIndex
CREATE INDEX "SanctionsList_name_idx" ON "SanctionsList"("name");

-- CreateIndex
CREATE INDEX "ScreeningResult_address_idx" ON "ScreeningResult"("address");

-- CreateIndex
CREATE INDEX "ScreeningResult_txHash_idx" ON "ScreeningResult"("txHash");

-- CreateIndex
CREATE INDEX "ScreeningResult_screenedAt_idx" ON "ScreeningResult"("screenedAt" DESC);

-- CreateIndex
CREATE INDEX "ScreeningResult_status_idx" ON "ScreeningResult"("status");

-- CreateIndex
CREATE INDEX "ScreeningResult_riskScore_idx" ON "ScreeningResult"("riskScore");

-- CreateIndex
CREATE INDEX "ScreeningResult_address_status_idx" ON "ScreeningResult"("address", "status");

-- CreateIndex
CREATE UNIQUE INDEX "TravelRuleRecord_txHash_key" ON "TravelRuleRecord"("txHash");

-- CreateIndex
CREATE INDEX "TravelRuleRecord_txHash_idx" ON "TravelRuleRecord"("txHash");

-- CreateIndex
CREATE INDEX "TravelRuleRecord_travelRuleStatus_idx" ON "TravelRuleRecord"("travelRuleStatus");

-- CreateIndex
CREATE INDEX "TravelRuleRecord_submittedAt_idx" ON "TravelRuleRecord"("submittedAt");

-- CreateIndex
CREATE INDEX "ComplianceReport_reportType_periodStart_idx" ON "ComplianceReport"("reportType", "periodStart" DESC);

-- CreateIndex
CREATE INDEX "ComplianceReport_generatedAt_idx" ON "ComplianceReport"("generatedAt" DESC);

-- CreateIndex
CREATE INDEX "ContractResourceMetric_contractAddress_idx" ON "ContractResourceMetric"("contractAddress");

-- CreateIndex
CREATE INDEX "ContractResourceMetric_ledgerSequence_idx" ON "ContractResourceMetric"("ledgerSequence");

-- CreateIndex
CREATE UNIQUE INDEX "ContractResourceMetric_contractAddress_transactionHash_key" ON "ContractResourceMetric"("contractAddress", "transactionHash");

-- CreateIndex
CREATE UNIQUE INDEX "TranslationKey_key_key" ON "TranslationKey"("key");

-- CreateIndex
CREATE INDEX "TranslationKey_key_idx" ON "TranslationKey"("key");

-- CreateIndex
CREATE INDEX "Translation_keyId_idx" ON "Translation"("keyId");

-- CreateIndex
CREATE INDEX "Translation_language_idx" ON "Translation"("language");

-- CreateIndex
CREATE UNIQUE INDEX "Translation_keyId_language_key" ON "Translation"("keyId", "language");

-- CreateIndex
CREATE UNIQUE INDEX "FeedChannel_name_key" ON "FeedChannel"("name");

-- CreateIndex
CREATE INDEX "FeedMessage_channelName_idx" ON "FeedMessage"("channelName");

-- CreateIndex
CREATE INDEX "FeedMessage_ledgerSequence_idx" ON "FeedMessage"("ledgerSequence");

-- CreateIndex
CREATE INDEX "FeedSubscription_channelName_idx" ON "FeedSubscription"("channelName");

-- CreateIndex
CREATE INDEX "FeedSubscription_status_idx" ON "FeedSubscription"("status");

-- CreateIndex
CREATE UNIQUE INDEX "EmergencyState_contractAddress_key" ON "EmergencyState"("contractAddress");

-- CreateIndex
CREATE INDEX "EmergencyState_contractAddress_idx" ON "EmergencyState"("contractAddress");

-- CreateIndex
CREATE INDEX "PauseEvent_contractAddress_idx" ON "PauseEvent"("contractAddress");

-- CreateIndex
CREATE INDEX "PauseEvent_eventType_idx" ON "PauseEvent"("eventType");

-- CreateIndex
CREATE INDEX "PauseEvent_timestamp_idx" ON "PauseEvent"("timestamp");

-- CreateIndex
CREATE INDEX "PauseEvent_pauserAddress_idx" ON "PauseEvent"("pauserAddress");

-- CreateIndex
CREATE UNIQUE INDEX "PauserAnalysis_contractAddress_key" ON "PauserAnalysis"("contractAddress");

-- CreateIndex
CREATE UNIQUE INDEX "RecoveryAnalysis_contractAddress_key" ON "RecoveryAnalysis"("contractAddress");

-- CreateIndex
CREATE INDEX "AlertConfiguration_userId_idx" ON "AlertConfiguration"("userId");

-- CreateIndex
CREATE INDEX "AlertConfiguration_contractAddress_idx" ON "AlertConfiguration"("contractAddress");

-- CreateIndex
CREATE INDEX "IncidentReport_contractAddress_idx" ON "IncidentReport"("contractAddress");

-- CreateIndex
CREATE INDEX "IncidentReport_status_idx" ON "IncidentReport"("status");

-- CreateIndex
CREATE INDEX "IncidentReport_severity_idx" ON "IncidentReport"("severity");

-- CreateIndex
CREATE INDEX "IncidentReport_createdAt_idx" ON "IncidentReport"("createdAt");

-- CreateIndex
CREATE INDEX "IncidentComment_incidentId_idx" ON "IncidentComment"("incidentId");

-- CreateIndex
CREATE UNIQUE INDEX "ProtocolHealthScore_contractAddress_key" ON "ProtocolHealthScore"("contractAddress");

-- CreateIndex
CREATE INDEX "ProtocolHealthScore_healthScore_idx" ON "ProtocolHealthScore"("healthScore");

-- CreateIndex
CREATE UNIQUE INDEX "StellarAccount_address_key" ON "StellarAccount"("address");

-- CreateIndex
CREATE UNIQUE INDEX "AccountTrustline_accountId_assetCode_assetIssuer_key" ON "AccountTrustline"("accountId", "assetCode", "assetIssuer");

-- CreateIndex
CREATE UNIQUE INDEX "AccountSigner_accountId_signerKey_key" ON "AccountSigner"("accountId", "signerKey");

-- CreateIndex
CREATE UNIQUE INDEX "StellarAsset_assetCode_assetIssuer_key" ON "StellarAsset"("assetCode", "assetIssuer");

-- CreateIndex
CREATE INDEX "UnifiedTransaction_sourceAccount_createdAt_idx" ON "UnifiedTransaction"("sourceAccount", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "UnifiedTransaction_network_txHash_key" ON "UnifiedTransaction"("network", "txHash");

-- CreateIndex
CREATE INDEX "AnchorsRegistry_homeDomain_idx" ON "AnchorsRegistry"("homeDomain");

-- CreateIndex
CREATE INDEX "AnchorsRegistry_status_idx" ON "AnchorsRegistry"("status");

-- CreateIndex
CREATE INDEX "AnchorReview_anchorId_idx" ON "AnchorReview"("anchorId");

-- CreateIndex
CREATE UNIQUE INDEX "BridgedAsset_sorobanContract_key" ON "BridgedAsset"("sorobanContract");

-- CreateIndex
CREATE UNIQUE INDEX "ComposedTransaction_txHash_key" ON "ComposedTransaction"("txHash");

-- CreateIndex
CREATE INDEX "ComposedTransaction_ledgerSeq_idx" ON "ComposedTransaction"("ledgerSeq");

-- CreateIndex
CREATE INDEX "ComposedTransaction_riskLevel_idx" ON "ComposedTransaction"("riskLevel");

-- CreateIndex
CREATE INDEX "ComposedTransaction_analysisStatus_idx" ON "ComposedTransaction"("analysisStatus");

-- CreateIndex
CREATE UNIQUE INDEX "CompositionPattern_name_key" ON "CompositionPattern"("name");

-- CreateIndex
CREATE INDEX "CompositionPattern_category_idx" ON "CompositionPattern"("category");

-- CreateIndex
CREATE INDEX "CompositionPattern_riskRating_idx" ON "CompositionPattern"("riskRating");

-- CreateIndex
CREATE INDEX "CompositionPatternInstance_txId_idx" ON "CompositionPatternInstance"("txId");

-- CreateIndex
CREATE INDEX "CompositionPatternInstance_patternId_idx" ON "CompositionPatternInstance"("patternId");

-- CreateIndex
CREATE UNIQUE INDEX "ContractComposability_contractAddress_key" ON "ContractComposability"("contractAddress");

-- CreateIndex
CREATE INDEX "ContractComposability_contractAddress_idx" ON "ContractComposability"("contractAddress");

-- CreateIndex
CREATE INDEX "ContractComposability_riskIncidents_idx" ON "ContractComposability"("riskIncidents");

-- CreateIndex
CREATE INDEX "CompositionAlert_txHash_idx" ON "CompositionAlert"("txHash");

-- CreateIndex
CREATE INDEX "CompositionAlert_contractAddress_idx" ON "CompositionAlert"("contractAddress");

-- CreateIndex
CREATE INDEX "CompositionAlert_severity_idx" ON "CompositionAlert"("severity");

-- CreateIndex
CREATE INDEX "CompositionAlert_exploitDetected_idx" ON "CompositionAlert"("exploitDetected");

-- CreateIndex
CREATE UNIQUE INDEX "ComposabilityStaticAnalysis_contractAddress_key" ON "ComposabilityStaticAnalysis"("contractAddress");

-- CreateIndex
CREATE UNIQUE INDEX "ComposabilityVerification_txHash_key" ON "ComposabilityVerification"("txHash");

-- CreateIndex
CREATE INDEX "ComposabilityVerification_verified_idx" ON "ComposabilityVerification"("verified");

-- CreateIndex
CREATE INDEX "ComposabilityFuzzCampaign_contractAddress_idx" ON "ComposabilityFuzzCampaign"("contractAddress");

-- CreateIndex
CREATE INDEX "ComposabilityFuzzCampaign_status_idx" ON "ComposabilityFuzzCampaign"("status");

-- CreateIndex
CREATE INDEX "ComposabilityExploit_patternCategory_idx" ON "ComposabilityExploit"("patternCategory");

-- CreateIndex
CREATE INDEX "ComposabilityExploit_severity_idx" ON "ComposabilityExploit"("severity");

-- CreateIndex
CREATE INDEX "EcosystemComposabilityIndex_computedAt_idx" ON "EcosystemComposabilityIndex"("computedAt");

-- CreateIndex
CREATE UNIQUE INDEX "MevVictim_address_key" ON "MevVictim"("address");

-- CreateIndex
CREATE INDEX "MevVictim_address_idx" ON "MevVictim"("address");

-- CreateIndex
CREATE UNIQUE INDEX "MevAttacker_address_key" ON "MevAttacker"("address");

-- CreateIndex
CREATE INDEX "MevAttacker_address_idx" ON "MevAttacker"("address");

-- CreateIndex
CREATE INDEX "MevAttacker_totalProfitUsd_idx" ON "MevAttacker"("totalProfitUsd");

-- CreateIndex
CREATE UNIQUE INDEX "MevEvent_txHash_key" ON "MevEvent"("txHash");

-- CreateIndex
CREATE INDEX "MevEvent_mevType_idx" ON "MevEvent"("mevType");

-- CreateIndex
CREATE INDEX "MevEvent_ledgerSeq_idx" ON "MevEvent"("ledgerSeq");

-- CreateIndex
CREATE INDEX "MevEvent_victimAddress_idx" ON "MevEvent"("victimAddress");

-- CreateIndex
CREATE INDEX "MevEvent_attackerAddress_idx" ON "MevEvent"("attackerAddress");

-- CreateIndex
CREATE INDEX "MevEvent_protocolAddress_idx" ON "MevEvent"("protocolAddress");

-- CreateIndex
CREATE INDEX "MevEvent_createdAt_idx" ON "MevEvent"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "ProtocolMevResistance_contractAddress_key" ON "ProtocolMevResistance"("contractAddress");

-- CreateIndex
CREATE INDEX "ProtocolMevResistance_contractAddress_idx" ON "ProtocolMevResistance"("contractAddress");

-- CreateIndex
CREATE INDEX "ProtocolMevResistance_score_idx" ON "ProtocolMevResistance"("score");

-- CreateIndex
CREATE INDEX "MevAlert_alertType_idx" ON "MevAlert"("alertType");

-- CreateIndex
CREATE INDEX "MevAlert_severity_idx" ON "MevAlert"("severity");

-- CreateIndex
CREATE INDEX "MevAlert_victimAddress_idx" ON "MevAlert"("victimAddress");

-- CreateIndex
CREATE INDEX "MevAlert_acknowledged_idx" ON "MevAlert"("acknowledged");

-- CreateIndex
CREATE INDEX "MevAlert_createdAt_idx" ON "MevAlert"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "BillingPlan_name_key" ON "BillingPlan"("name");

-- CreateIndex
CREATE UNIQUE INDEX "Developer_email_key" ON "Developer"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Developer_githubId_key" ON "Developer"("githubId");

-- CreateIndex
CREATE INDEX "Developer_email_idx" ON "Developer"("email");

-- CreateIndex
CREATE INDEX "Developer_planId_idx" ON "Developer"("planId");

-- CreateIndex
CREATE INDEX "DevApiKey_developerId_idx" ON "DevApiKey"("developerId");

-- CreateIndex
CREATE INDEX "DevApiKey_keyPrefix_idx" ON "DevApiKey"("keyPrefix");

-- CreateIndex
CREATE INDEX "DevApiKey_keyHash_idx" ON "DevApiKey"("keyHash");

-- CreateIndex
CREATE INDEX "DevApiKey_status_idx" ON "DevApiKey"("status");

-- CreateIndex
CREATE INDEX "DevApiKey_tier_idx" ON "DevApiKey"("tier");

-- CreateIndex
CREATE INDEX "DevWebhook_developerId_idx" ON "DevWebhook"("developerId");

-- CreateIndex
CREATE INDEX "DevWebhookDelivery_webhookId_idx" ON "DevWebhookDelivery"("webhookId");

-- CreateIndex
CREATE INDEX "DevWebhookDelivery_delivered_idx" ON "DevWebhookDelivery"("delivered");

-- CreateIndex
CREATE INDEX "DevWebhookDelivery_expiresAt_idx" ON "DevWebhookDelivery"("expiresAt");

-- CreateIndex
CREATE INDEX "UsageRecord_developerId_idx" ON "UsageRecord"("developerId");

-- CreateIndex
CREATE INDEX "UsageRecord_apiKeyId_idx" ON "UsageRecord"("apiKeyId");

-- CreateIndex
CREATE INDEX "UsageRecord_createdAt_idx" ON "UsageRecord"("createdAt");

-- CreateIndex
CREATE INDEX "UsageRecord_endpoint_idx" ON "UsageRecord"("endpoint");

-- CreateIndex
CREATE INDEX "ScheduledOperation_contractAddress_idx" ON "ScheduledOperation"("contractAddress");

-- CreateIndex
CREATE INDEX "ScheduledOperation_timerType_idx" ON "ScheduledOperation"("timerType");

-- CreateIndex
CREATE INDEX "ScheduledOperation_status_idx" ON "ScheduledOperation"("status");

-- CreateIndex
CREATE INDEX "ScheduledOperation_nextTriggerAt_idx" ON "ScheduledOperation"("nextTriggerAt");

-- CreateIndex
CREATE INDEX "ScheduledOperation_triggerTime_idx" ON "ScheduledOperation"("triggerTime");

-- CreateIndex
CREATE INDEX "VestingSchedule_beneficiary_idx" ON "VestingSchedule"("beneficiary");

-- CreateIndex
CREATE INDEX "VestingSchedule_contractAddress_idx" ON "VestingSchedule"("contractAddress");

-- CreateIndex
CREATE INDEX "VestingSchedule_nextUnlockDate_idx" ON "VestingSchedule"("nextUnlockDate");

-- CreateIndex
CREATE INDEX "VestingSchedule_status_idx" ON "VestingSchedule"("status");

-- CreateIndex
CREATE INDEX "GovernanceTimelock_contractAddress_idx" ON "GovernanceTimelock"("contractAddress");

-- CreateIndex
CREATE INDEX "GovernanceTimelock_status_idx" ON "GovernanceTimelock"("status");

-- CreateIndex
CREATE INDEX "GovernanceTimelock_executionTime_idx" ON "GovernanceTimelock"("executionTime");

-- CreateIndex
CREATE INDEX "CronJob_contractAddress_idx" ON "CronJob"("contractAddress");

-- CreateIndex
CREATE INDEX "CronJob_nextRunAt_idx" ON "CronJob"("nextRunAt");

-- CreateIndex
CREATE INDEX "CronExecution_cronJobId_executedAt_idx" ON "CronExecution"("cronJobId", "executedAt");

-- CreateIndex
CREATE INDEX "TimerAlert_scheduledOpId_idx" ON "TimerAlert"("scheduledOpId");

-- CreateIndex
CREATE INDEX "TimerAlert_triggerTime_idx" ON "TimerAlert"("triggerTime");

-- CreateIndex
CREATE UNIQUE INDEX "DexPool_contractAddress_key" ON "DexPool"("contractAddress");

-- CreateIndex
CREATE UNIQUE INDEX "DexPool_poolAddress_key" ON "DexPool"("poolAddress");

-- CreateIndex
CREATE INDEX "DexPool_dexName_idx" ON "DexPool"("dexName");

-- CreateIndex
CREATE INDEX "DexPool_tokenA_tokenB_idx" ON "DexPool"("tokenA", "tokenB");

-- CreateIndex
CREATE INDEX "DexPool_isActive_idx" ON "DexPool"("isActive");

-- CreateIndex
CREATE INDEX "PoolPrice_poolId_timestamp_idx" ON "PoolPrice"("poolId", "timestamp");

-- CreateIndex
CREATE INDEX "PoolPrice_timestamp_idx" ON "PoolPrice"("timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "PoolPrice_poolId_blockNumber_key" ON "PoolPrice"("poolId", "blockNumber");

-- CreateIndex
CREATE INDEX "PriceDeviation_tokenA_tokenB_timestamp_idx" ON "PriceDeviation"("tokenA", "tokenB", "timestamp");

-- CreateIndex
CREATE INDEX "PriceDeviation_deviationPercentage_idx" ON "PriceDeviation"("deviationPercentage");

-- CreateIndex
CREATE INDEX "PriceDeviation_timestamp_idx" ON "PriceDeviation"("timestamp");

-- CreateIndex
CREATE INDEX "PriceDeviation_poolIdA_idx" ON "PriceDeviation"("poolIdA");

-- CreateIndex
CREATE INDEX "PriceDeviation_poolIdB_idx" ON "PriceDeviation"("poolIdB");

-- CreateIndex
CREATE INDEX "ArbitrageOpportunity_status_detectedAt_idx" ON "ArbitrageOpportunity"("status", "detectedAt");

-- CreateIndex
CREATE INDEX "ArbitrageOpportunity_pair_status_idx" ON "ArbitrageOpportunity"("pair", "status");

-- CreateIndex
CREATE INDEX "ArbitrageOpportunity_type_idx" ON "ArbitrageOpportunity"("type");

-- CreateIndex
CREATE INDEX "ArbitrageOpportunity_profitPercentage_idx" ON "ArbitrageOpportunity"("profitPercentage");

-- CreateIndex
CREATE INDEX "ArbitrageOpportunity_detectedAt_idx" ON "ArbitrageOpportunity"("detectedAt");

-- CreateIndex
CREATE UNIQUE INDEX "MevOpportunityScore_opportunityId_key" ON "MevOpportunityScore"("opportunityId");

-- CreateIndex
CREATE INDEX "MevOpportunityScore_overallScore_idx" ON "MevOpportunityScore"("overallScore");

-- CreateIndex
CREATE INDEX "MevOpportunityScore_recommendation_idx" ON "MevOpportunityScore"("recommendation");

-- CreateIndex
CREATE INDEX "ArbitrageExecution_opportunityId_idx" ON "ArbitrageExecution"("opportunityId");

-- CreateIndex
CREATE INDEX "ArbitrageExecution_searcherAddress_idx" ON "ArbitrageExecution"("searcherAddress");

-- CreateIndex
CREATE INDEX "ArbitrageExecution_success_idx" ON "ArbitrageExecution"("success");

-- CreateIndex
CREATE INDEX "ArbitrageExecution_executedAt_idx" ON "ArbitrageExecution"("executedAt");

-- CreateIndex
CREATE UNIQUE INDEX "ArbitrageBot_address_key" ON "ArbitrageBot"("address");

-- CreateIndex
CREATE INDEX "ArbitrageBot_totalProfit_idx" ON "ArbitrageBot"("totalProfit");

-- CreateIndex
CREATE INDEX "ArbitrageBot_isActive_idx" ON "ArbitrageBot"("isActive");

-- CreateIndex
CREATE INDEX "ArbitrageBot_lastSeen_idx" ON "ArbitrageBot"("lastSeen");

-- CreateIndex
CREATE INDEX "SandwichAttack_victimAddress_idx" ON "SandwichAttack"("victimAddress");

-- CreateIndex
CREATE INDEX "SandwichAttack_attackerAddress_idx" ON "SandwichAttack"("attackerAddress");

-- CreateIndex
CREATE INDEX "SandwichAttack_timestamp_idx" ON "SandwichAttack"("timestamp");

-- CreateIndex
CREATE INDEX "SandwichAttack_pair_idx" ON "SandwichAttack"("pair");

-- CreateIndex
CREATE INDEX "ArbitrageAlert_isActive_idx" ON "ArbitrageAlert"("isActive");

-- CreateIndex
CREATE INDEX "ProtocolEconomicsSnapshot_bucket_bucketStart_idx" ON "ProtocolEconomicsSnapshot"("bucket", "bucketStart");

-- CreateIndex
CREATE UNIQUE INDEX "ProtocolEconomicsSnapshot_bucket_bucketStart_key" ON "ProtocolEconomicsSnapshot"("bucket", "bucketStart");

-- CreateIndex
CREATE UNIQUE INDEX "FeatureDefinition_name_key" ON "FeatureDefinition"("name");

-- CreateIndex
CREATE INDEX "FeatureDefinition_category_idx" ON "FeatureDefinition"("category");

-- CreateIndex
CREATE INDEX "FeatureValue_featureId_timestamp_idx" ON "FeatureValue"("featureId", "timestamp");

-- CreateIndex
CREATE INDEX "FeatureValue_featureId_timestamp_id_idx" ON "FeatureValue"("featureId", "timestamp", "id");

-- CreateIndex
CREATE INDEX "PredictionScenario_scenarioName_idx" ON "PredictionScenario"("scenarioName");

-- CreateIndex
CREATE UNIQUE INDEX "PredictiveApiKey_key_key" ON "PredictiveApiKey"("key");

-- CreateIndex
CREATE INDEX "PredictiveApiKey_key_idx" ON "PredictiveApiKey"("key");

-- CreateIndex
CREATE INDEX "AmmPool_poolAddress_idx" ON "AmmPool"("poolAddress");

-- CreateIndex
CREATE UNIQUE INDEX "Attestation_uid_key" ON "Attestation"("uid");

-- CreateIndex
CREATE INDEX "Attestation_profileId_idx" ON "Attestation"("profileId");

-- CreateIndex
CREATE INDEX "Attestation_chainId_idx" ON "Attestation"("chainId");

-- CreateIndex
CREATE INDEX "BackfillRequest_userId_idx" ON "BackfillRequest"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "ContractFactory_parentContractAddress_childContractAddress_key" ON "ContractFactory"("parentContractAddress", "childContractAddress");

-- CreateIndex
CREATE INDEX "DtccSettlementBridge_dtccSettlementId_idx" ON "DtccSettlementBridge"("dtccSettlementId");

-- CreateIndex
CREATE INDEX "Endorsement_profileId_idx" ON "Endorsement"("profileId");

-- CreateIndex
CREATE INDEX "ExportJob_developerId_idx" ON "ExportJob"("developerId");

-- CreateIndex
CREATE INDEX "ExportJob_developerId_createdAt_idx" ON "ExportJob"("developerId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "FreezeViolation_transactionHash_key" ON "FreezeViolation"("transactionHash");

-- CreateIndex
CREATE UNIQUE INDEX "FrozenLedgerKey_ledgerKey_key" ON "FrozenLedgerKey"("ledgerKey");

-- CreateIndex
CREATE INDEX "FuzzFinding_runId_idx" ON "FuzzFinding"("runId");

-- CreateIndex
CREATE INDEX "FuzzFinding_fuzzRunId_idx" ON "FuzzFinding"("fuzzRunId");

-- CreateIndex
CREATE UNIQUE INDEX "GasAnalyticsSnapshot_bucket_bucketStart_key" ON "GasAnalyticsSnapshot"("bucket", "bucketStart");

-- CreateIndex
CREATE UNIQUE INDEX "GovernanceContract_contractAddress_key" ON "GovernanceContract"("contractAddress");

-- CreateIndex
CREATE UNIQUE INDEX "GovernanceDelegate_contractAddress_delegatee_key" ON "GovernanceDelegate"("contractAddress", "delegatee");

-- CreateIndex
CREATE UNIQUE INDEX "GovernanceProposal_contractAddress_proposalId_key" ON "GovernanceProposal"("contractAddress", "proposalId");

-- CreateIndex
CREATE INDEX "GovernanceVote_proposalId_idx" ON "GovernanceVote"("proposalId");

-- CreateIndex
CREATE UNIQUE INDEX "GovernanceVote_contractAddress_proposalId_voter_key" ON "GovernanceVote"("contractAddress", "proposalId", "voter");

-- CreateIndex
CREATE UNIQUE INDEX "LinkedIdentity_profileId_chainId_address_key" ON "LinkedIdentity"("profileId", "chainId", "address");

-- CreateIndex
CREATE UNIQUE INDEX "NetworkNode_publicKey_key" ON "NetworkNode"("publicKey");

-- CreateIndex
CREATE UNIQUE INDEX "PrivacyComplianceReport_address_key" ON "PrivacyComplianceReport"("address");

-- CreateIndex
CREATE UNIQUE INDEX "PrivacyTransaction_txHash_key" ON "PrivacyTransaction"("txHash");

-- CreateIndex
CREATE UNIQUE INDEX "ReentrancyAlert_transactionHash_key" ON "ReentrancyAlert"("transactionHash");

-- CreateIndex
CREATE INDEX "ReputationBadge_profileId_idx" ON "ReputationBadge"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "ReputationGovernanceVote_proposalId_voter_key" ON "ReputationGovernanceVote"("proposalId", "voter");

-- CreateIndex
CREATE UNIQUE INDEX "ReputationProfile_address_key" ON "ReputationProfile"("address");

-- CreateIndex
CREATE INDEX "ReputationTrustConnection_profileId_idx" ON "ReputationTrustConnection"("profileId");

-- CreateIndex
CREATE INDEX "ReputationSignal_profileId_idx" ON "ReputationSignal"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "RwaComplianceEvent_transactionHash_key" ON "RwaComplianceEvent"("transactionHash");

-- CreateIndex
CREATE UNIQUE INDEX "SandboxAccount_sessionId_publicKey_key" ON "SandboxAccount"("sessionId", "publicKey");

-- CreateIndex
CREATE INDEX "SandboxCall_sessionId_idx" ON "SandboxCall"("sessionId");

-- CreateIndex
CREATE INDEX "SandboxCall_contractId_idx" ON "SandboxCall"("contractId");

-- CreateIndex
CREATE UNIQUE INDEX "SandboxContract_sessionId_contractId_key" ON "SandboxContract"("sessionId", "contractId");

-- CreateIndex
CREATE INDEX "SandboxSession_userId_idx" ON "SandboxSession"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "SandboxShare_shareId_key" ON "SandboxShare"("shareId");

-- CreateIndex
CREATE UNIQUE INDEX "SettlementBatchSummary_contractAddress_windowKey_key" ON "SettlementBatchSummary"("contractAddress", "windowKey");

-- CreateIndex
CREATE UNIQUE INDEX "SignatureInspection_transactionHash_key" ON "SignatureInspection"("transactionHash");

-- CreateIndex
CREATE UNIQUE INDEX "ThreatAdvisory_cveId_key" ON "ThreatAdvisory"("cveId");

-- CreateIndex
CREATE UNIQUE INDEX "ThreatAdvisory_ghsaId_key" ON "ThreatAdvisory"("ghsaId");

-- CreateIndex
CREATE UNIQUE INDEX "TipSubscription_channel_target_key" ON "TipSubscription"("channel", "target");

-- CreateIndex
CREATE UNIQUE INDEX "TokenPrice_tokenAddress_key" ON "TokenPrice"("tokenAddress");

-- CreateIndex
CREATE INDEX "TokenPrice_updatedAt_idx" ON "TokenPrice"("updatedAt" DESC);

-- CreateIndex
CREATE INDEX "TokenPrice_volume24hUsd_idx" ON "TokenPrice"("volume24hUsd" DESC);

-- CreateIndex
CREATE INDEX "TokenPriceHistory_tokenAddress_timestamp_idx" ON "TokenPriceHistory"("tokenAddress", "timestamp" DESC);

-- CreateIndex
CREATE INDEX "TokenPriceHistory_timestamp_idx" ON "TokenPriceHistory"("timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "TokenMarketData_tokenAddress_key" ON "TokenMarketData"("tokenAddress");

-- CreateIndex
CREATE INDEX "TokenMarketData_holderCount_idx" ON "TokenMarketData"("holderCount" DESC);

-- CreateIndex
CREATE INDEX "TokenMarketData_transferCount24h_idx" ON "TokenMarketData"("transferCount24h" DESC);

-- CreateIndex
CREATE INDEX "PriceAlert_userId_idx" ON "PriceAlert"("userId");

-- CreateIndex
CREATE INDEX "PriceAlert_tokenAddress_idx" ON "PriceAlert"("tokenAddress");

-- CreateIndex
CREATE INDEX "VerifiableCredential_profileId_idx" ON "VerifiableCredential"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "VulnerabilitySource_name_key" ON "VulnerabilitySource"("name");

-- CreateIndex
CREATE INDEX "WebhookDelivery_subscriptionId_idx" ON "WebhookDelivery"("subscriptionId");

-- CreateIndex
CREATE INDEX "WebhookDelivery_expiresAt_idx" ON "WebhookDelivery"("expiresAt");

-- CreateIndex
CREATE INDEX "WebhookDelivery_status_nextRetryAt_processingStatus_idx" ON "WebhookDelivery"("status", "nextRetryAt", "processingStatus");

-- CreateIndex
CREATE INDEX "WebhookSubscription_apiKeyId_idx" ON "WebhookSubscription"("apiKeyId");

-- CreateIndex
CREATE INDEX "YieldHistorySnapshot_opportunityId_idx" ON "YieldHistorySnapshot"("opportunityId");

-- CreateIndex
CREATE INDEX "call_graph_vertices_tx_hash_idx" ON "call_graph_vertices"("tx_hash");

-- CreateIndex
CREATE INDEX "call_graph_vertices_contract_address_idx" ON "call_graph_vertices"("contract_address");

-- CreateIndex
CREATE INDEX "call_graph_edges_tx_hash_idx" ON "call_graph_edges"("tx_hash");

-- CreateIndex
CREATE INDEX "call_graph_edges_from_vertex_id_idx" ON "call_graph_edges"("from_vertex_id");

-- CreateIndex
CREATE INDEX "call_graph_edges_to_vertex_id_idx" ON "call_graph_edges"("to_vertex_id");

-- CreateIndex
CREATE INDEX "reentrancy_findings_tx_hash_idx" ON "reentrancy_findings"("tx_hash");

-- CreateIndex
CREATE INDEX "reentrancy_findings_contract_address_idx" ON "reentrancy_findings"("contract_address");

-- CreateIndex
CREATE INDEX "reentrancy_findings_severity_idx" ON "reentrancy_findings"("severity");

-- CreateIndex
CREATE UNIQUE INDEX "contract_risk_scores_contract_address_key" ON "contract_risk_scores"("contract_address");

-- CreateIndex
CREATE INDEX "reentrancy_alerts_contract_address_created_at_idx" ON "reentrancy_alerts"("contract_address", "created_at" DESC);

-- CreateIndex
CREATE INDEX "nl_queries_userId_createdAt_idx" ON "nl_queries"("userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "nl_queries_createdAt_idx" ON "nl_queries"("createdAt" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "nl_query_contexts_query_id_key" ON "nl_query_contexts"("query_id");

-- CreateIndex
CREATE INDEX "nl_query_contexts_session_id_idx" ON "nl_query_contexts"("session_id");

-- CreateIndex
CREATE INDEX "nl_sessions_userId_idx" ON "nl_sessions"("userId");

-- CreateIndex
CREATE INDEX "saved_queries_userId_idx" ON "saved_queries"("userId");

-- CreateIndex
CREATE INDEX "saved_queries_query_id_idx" ON "saved_queries"("query_id");

-- CreateIndex
CREATE UNIQUE INDEX "nl_embeddings_query_key" ON "nl_embeddings"("query");

-- CreateIndex
CREATE INDEX "nl_query_templates_is_public_idx" ON "nl_query_templates"("is_public");

-- CreateIndex
CREATE INDEX "nl_query_templates_category_idx" ON "nl_query_templates"("category");

-- CreateIndex
CREATE INDEX "nl_reports_userId_idx" ON "nl_reports"("userId");

-- CreateIndex
CREATE INDEX "nl_report_history_report_id_ran_at_idx" ON "nl_report_history"("report_id", "ran_at" DESC);

-- CreateIndex
CREATE INDEX "nl_alerts_userId_idx" ON "nl_alerts"("userId");

-- CreateIndex
CREATE INDEX "nl_alerts_active_idx" ON "nl_alerts"("active");

-- CreateIndex
CREATE UNIQUE INDEX "archival_nodes_address_key" ON "archival_nodes"("address");

-- CreateIndex
CREATE INDEX "archival_nodes_status_idx" ON "archival_nodes"("status");

-- CreateIndex
CREATE INDEX "archival_nodes_reputation_idx" ON "archival_nodes"("reputation");

-- CreateIndex
CREATE INDEX "archival_epochs_nodeId_idx" ON "archival_epochs"("nodeId");

-- CreateIndex
CREATE INDEX "archival_epochs_epochId_idx" ON "archival_epochs"("epochId");

-- CreateIndex
CREATE INDEX "archival_epochs_status_idx" ON "archival_epochs"("status");

-- CreateIndex
CREATE INDEX "storage_challenges_nodeId_idx" ON "storage_challenges"("nodeId");

-- CreateIndex
CREATE INDEX "storage_challenges_epochId_idx" ON "storage_challenges"("epochId");

-- CreateIndex
CREATE INDEX "storage_challenges_status_idx" ON "storage_challenges"("status");

-- CreateIndex
CREATE INDEX "data_retrievals_requester_idx" ON "data_retrievals"("requester");

-- CreateIndex
CREATE INDEX "data_retrievals_epochId_idx" ON "data_retrievals"("epochId");

-- CreateIndex
CREATE INDEX "data_retrievals_nodeId_idx" ON "data_retrievals"("nodeId");

-- CreateIndex
CREATE INDEX "data_retrievals_status_idx" ON "data_retrievals"("status");

-- CreateIndex
CREATE INDEX "sla_offers_nodeId_idx" ON "sla_offers"("nodeId");

-- CreateIndex
CREATE INDEX "sla_offers_tier_idx" ON "sla_offers"("tier");

-- CreateIndex
CREATE INDEX "sla_acceptances_offerId_idx" ON "sla_acceptances"("offerId");

-- CreateIndex
CREATE INDEX "sla_acceptances_requester_idx" ON "sla_acceptances"("requester");

-- CreateIndex
CREATE INDEX "archival_slashes_nodeId_idx" ON "archival_slashes"("nodeId");

-- CreateIndex
CREATE INDEX "archival_slashes_challengeId_idx" ON "archival_slashes"("challengeId");

-- CreateIndex
CREATE INDEX "archival_appeals_slashId_idx" ON "archival_appeals"("slashId");

-- CreateIndex
CREATE UNIQUE INDEX "NftCollection_contractAddress_key" ON "NftCollection"("contractAddress");

-- CreateIndex
CREATE INDEX "NftCollection_volume24h_idx" ON "NftCollection"("volume24h" DESC);

-- CreateIndex
CREATE INDEX "NftCollection_volume7d_idx" ON "NftCollection"("volume7d" DESC);

-- CreateIndex
CREATE INDEX "NftCollection_uniqueHolders_idx" ON "NftCollection"("uniqueHolders" DESC);

-- CreateIndex
CREATE INDEX "NftCollection_marketCap_idx" ON "NftCollection"("marketCap" DESC);

-- CreateIndex
CREATE INDEX "NftCollection_floorPrice_idx" ON "NftCollection"("floorPrice" DESC);

-- CreateIndex
CREATE INDEX "NftCollection_category_idx" ON "NftCollection"("category");

-- CreateIndex
CREATE INDEX "NftItem_owner_idx" ON "NftItem"("owner");

-- CreateIndex
CREATE INDEX "NftItem_rarityScore_idx" ON "NftItem"("rarityScore" DESC);

-- CreateIndex
CREATE INDEX "NftItem_lastSaleAt_idx" ON "NftItem"("lastSaleAt" DESC);

-- CreateIndex
CREATE INDEX "NftItem_collectionId_idx" ON "NftItem"("collectionId");

-- CreateIndex
CREATE UNIQUE INDEX "NftItem_collectionId_tokenId_key" ON "NftItem"("collectionId", "tokenId");

-- CreateIndex
CREATE INDEX "NftTrait_collectionId_idx" ON "NftTrait"("collectionId");

-- CreateIndex
CREATE UNIQUE INDEX "NftTrait_collectionId_traitType_traitValue_key" ON "NftTrait"("collectionId", "traitType", "traitValue");

-- CreateIndex
CREATE UNIQUE INDEX "NftSale_txHash_key" ON "NftSale"("txHash");

-- CreateIndex
CREATE INDEX "NftSale_collectionId_saleAt_idx" ON "NftSale"("collectionId", "saleAt");

-- CreateIndex
CREATE INDEX "NftSale_seller_idx" ON "NftSale"("seller");

-- CreateIndex
CREATE INDEX "NftSale_buyer_idx" ON "NftSale"("buyer");

-- CreateIndex
CREATE INDEX "NftSale_isWashTrade_idx" ON "NftSale"("isWashTrade");

-- CreateIndex
CREATE INDEX "NftListing_collectionId_status_idx" ON "NftListing"("collectionId", "status");

-- CreateIndex
CREATE INDEX "NftListing_seller_idx" ON "NftListing"("seller");

-- CreateIndex
CREATE INDEX "NftCollectionStats_collectionId_timestamp_idx" ON "NftCollectionStats"("collectionId", "timestamp" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "NftCollectionStats_collectionId_timestamp_key" ON "NftCollectionStats"("collectionId", "timestamp");

-- CreateIndex
CREATE INDEX "NftPortfolio_userId_idx" ON "NftPortfolio"("userId");

-- CreateIndex
CREATE INDEX "NftPortfolio_owner_idx" ON "NftPortfolio"("owner");

-- CreateIndex
CREATE INDEX "NftActivity_collectionId_occurredAt_idx" ON "NftActivity"("collectionId", "occurredAt" DESC);

-- CreateIndex
CREATE INDEX "NftActivity_activityType_occurredAt_idx" ON "NftActivity"("activityType", "occurredAt" DESC);

-- CreateIndex
CREATE INDEX "NftActivity_txHash_idx" ON "NftActivity"("txHash");

-- CreateIndex
CREATE UNIQUE INDEX "NftMarketplace_contractAddress_key" ON "NftMarketplace"("contractAddress");

-- CreateIndex
CREATE INDEX "NftMarketplace_isActive_idx" ON "NftMarketplace"("isActive");

-- CreateIndex
CREATE INDEX "ApiAuditLog_apiKeyId_idx" ON "ApiAuditLog"("apiKeyId");

-- CreateIndex
CREATE INDEX "ApiAuditLog_ip_idx" ON "ApiAuditLog"("ip");

-- CreateIndex
CREATE INDEX "ApiAuditLog_createdAt_idx" ON "ApiAuditLog"("createdAt" DESC);

-- CreateIndex
CREATE INDEX "ApiAuditLog_endpoint_idx" ON "ApiAuditLog"("endpoint");

-- CreateIndex
CREATE INDEX "ApiAuditLog_isRateLimited_idx" ON "ApiAuditLog"("isRateLimited");

-- CreateIndex
CREATE INDEX "AbuseEvent_ip_idx" ON "AbuseEvent"("ip");

-- CreateIndex
CREATE INDEX "AbuseEvent_apiKeyId_idx" ON "AbuseEvent"("apiKeyId");

-- CreateIndex
CREATE INDEX "AbuseEvent_pattern_idx" ON "AbuseEvent"("pattern");

-- CreateIndex
CREATE INDEX "AbuseEvent_createdAt_idx" ON "AbuseEvent"("createdAt" DESC);

-- CreateIndex
CREATE INDEX "AbuseEvent_blockedUntil_idx" ON "AbuseEvent"("blockedUntil");

-- CreateIndex
CREATE UNIQUE INDEX "bridge_transactions_transactionHash_key" ON "bridge_transactions"("transactionHash");

-- CreateIndex
CREATE INDEX "bridge_transactions_protocol_idx" ON "bridge_transactions"("protocol");

-- CreateIndex
CREATE INDEX "bridge_transactions_sourceChain_idx" ON "bridge_transactions"("sourceChain");

-- CreateIndex
CREATE INDEX "bridge_transactions_destinationChain_idx" ON "bridge_transactions"("destinationChain");

-- CreateIndex
CREATE INDEX "bridge_transactions_status_idx" ON "bridge_transactions"("status");

-- CreateIndex
CREATE INDEX "bridge_transactions_sender_idx" ON "bridge_transactions"("sender");

-- CreateIndex
CREATE INDEX "bridge_transactions_recipient_idx" ON "bridge_transactions"("recipient");

-- CreateIndex
CREATE INDEX "bridge_transactions_createdAt_idx" ON "bridge_transactions"("createdAt");

-- CreateIndex
CREATE INDEX "bridge_alerts_type_idx" ON "bridge_alerts"("type");

-- CreateIndex
CREATE INDEX "bridge_alerts_severity_idx" ON "bridge_alerts"("severity");

-- CreateIndex
CREATE INDEX "bridge_alerts_address_idx" ON "bridge_alerts"("address");

-- CreateIndex
CREATE INDEX "bridge_alerts_triggeredAt_idx" ON "bridge_alerts"("triggeredAt");

-- CreateIndex
CREATE INDEX "monitored_addresses_address_idx" ON "monitored_addresses"("address");

-- CreateIndex
CREATE INDEX "monitored_addresses_chain_idx" ON "monitored_addresses"("chain");

-- CreateIndex
CREATE UNIQUE INDEX "monitored_addresses_address_chain_key" ON "monitored_addresses"("address", "chain");

-- CreateIndex
CREATE INDEX "bridge_volumes_protocol_period_idx" ON "bridge_volumes"("protocol", "period");

-- CreateIndex
CREATE INDEX "bridge_volumes_chain_period_idx" ON "bridge_volumes"("chain", "period");

-- CreateIndex
CREATE INDEX "bridge_volumes_periodStart_idx" ON "bridge_volumes"("periodStart");

-- CreateIndex
CREATE UNIQUE INDEX "bridge_volumes_protocol_chain_asset_period_periodStart_key" ON "bridge_volumes"("protocol", "chain", "asset", "period", "periodStart");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_users_address_key" ON "wallet_users"("address");

-- CreateIndex
CREATE INDEX "wallet_users_address_idx" ON "wallet_users"("address");

-- CreateIndex
CREATE INDEX "auth_sessions_userId_idx" ON "auth_sessions"("userId");

-- CreateIndex
CREATE INDEX "auth_sessions_tokenHash_idx" ON "auth_sessions"("tokenHash");

-- CreateIndex
CREATE INDEX "auth_sessions_refreshTokenHash_idx" ON "auth_sessions"("refreshTokenHash");

-- CreateIndex
CREATE INDEX "auth_events_userId_idx" ON "auth_events"("userId");

-- CreateIndex
CREATE INDEX "auth_events_eventType_idx" ON "auth_events"("eventType");

-- CreateIndex
CREATE INDEX "auth_events_createdAt_idx" ON "auth_events"("createdAt");

-- CreateIndex
CREATE INDEX "auth_webhooks_userId_idx" ON "auth_webhooks"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "multisig_wallets_walletAddress_key" ON "multisig_wallets"("walletAddress");

-- CreateIndex
CREATE UNIQUE INDEX "oauth_apps_clientId_key" ON "oauth_apps"("clientId");

-- CreateIndex
CREATE INDEX "oauth_apps_ownerId_idx" ON "oauth_apps"("ownerId");

-- CreateIndex
CREATE UNIQUE INDEX "oauth_codes_code_key" ON "oauth_codes"("code");

-- CreateIndex
CREATE INDEX "oauth_codes_clientId_idx" ON "oauth_codes"("clientId");

-- CreateIndex
CREATE INDEX "oauth_codes_userId_idx" ON "oauth_codes"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "wasm_abi_extracts_contractAddress_key" ON "wasm_abi_extracts"("contractAddress");

-- CreateIndex
CREATE INDEX "wasm_abi_extracts_contractAddress_idx" ON "wasm_abi_extracts"("contractAddress");

-- CreateIndex
CREATE INDEX "wasm_abi_extracts_source_idx" ON "wasm_abi_extracts"("source");

-- CreateIndex
CREATE INDEX "abi_coverage_reports_contractAddress_idx" ON "abi_coverage_reports"("contractAddress");

-- CreateIndex
CREATE INDEX "abi_coverage_reports_createdAt_idx" ON "abi_coverage_reports"("createdAt");

-- CreateIndex
CREATE INDEX "abi_community_contributions_address_idx" ON "abi_community_contributions"("address");

-- AddForeignKey
ALTER TABLE "WasmUpgradeHistory" ADD CONSTRAINT "WasmUpgradeHistory_contractAddress_fkey" FOREIGN KEY ("contractAddress") REFERENCES "Contract"("address") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_ledgerSequence_fkey" FOREIGN KEY ("ledgerSequence") REFERENCES "Ledger"("sequence") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_contractAddress_fkey" FOREIGN KEY ("contractAddress") REFERENCES "Contract"("address") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_ledgerSequence_fkey" FOREIGN KEY ("ledgerSequence") REFERENCES "Ledger"("sequence") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_transactionHash_fkey" FOREIGN KEY ("transactionHash") REFERENCES "Transaction"("hash") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Event" ADD CONSTRAINT "Event_contractAddress_fkey" FOREIGN KEY ("contractAddress") REFERENCES "Contract"("address") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SponsoredTransaction" ADD CONSTRAINT "SponsoredTransaction_walletAddress_fkey" FOREIGN KEY ("walletAddress") REFERENCES "SmartWallet"("address") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Translation" ADD CONSTRAINT "Translation_keyId_fkey" FOREIGN KEY ("keyId") REFERENCES "TranslationKey"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "IncidentComment" ADD CONSTRAINT "IncidentComment_incidentId_fkey" FOREIGN KEY ("incidentId") REFERENCES "IncidentReport"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccountTrustline" ADD CONSTRAINT "AccountTrustline_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "StellarAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccountSigner" ADD CONSTRAINT "AccountSigner_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "StellarAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnchorReview" ADD CONSTRAINT "AnchorReview_anchorId_fkey" FOREIGN KEY ("anchorId") REFERENCES "AnchorsRegistry"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompositionPatternInstance" ADD CONSTRAINT "CompositionPatternInstance_txId_fkey" FOREIGN KEY ("txId") REFERENCES "ComposedTransaction"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompositionPatternInstance" ADD CONSTRAINT "CompositionPatternInstance_patternId_fkey" FOREIGN KEY ("patternId") REFERENCES "CompositionPattern"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CompositionAlert" ADD CONSTRAINT "CompositionAlert_patternId_fkey" FOREIGN KEY ("patternId") REFERENCES "CompositionPattern"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MevEvent" ADD CONSTRAINT "MevEvent_victimAddress_fkey" FOREIGN KEY ("victimAddress") REFERENCES "MevVictim"("address") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MevEvent" ADD CONSTRAINT "MevEvent_attackerAddress_fkey" FOREIGN KEY ("attackerAddress") REFERENCES "MevAttacker"("address") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Developer" ADD CONSTRAINT "Developer_planId_fkey" FOREIGN KEY ("planId") REFERENCES "BillingPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DevApiKey" ADD CONSTRAINT "DevApiKey_developerId_fkey" FOREIGN KEY ("developerId") REFERENCES "Developer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DevWebhook" ADD CONSTRAINT "DevWebhook_developerId_fkey" FOREIGN KEY ("developerId") REFERENCES "Developer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DevWebhookDelivery" ADD CONSTRAINT "DevWebhookDelivery_webhookId_fkey" FOREIGN KEY ("webhookId") REFERENCES "DevWebhook"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UsageRecord" ADD CONSTRAINT "UsageRecord_developerId_fkey" FOREIGN KEY ("developerId") REFERENCES "Developer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UsageRecord" ADD CONSTRAINT "UsageRecord_apiKeyId_fkey" FOREIGN KEY ("apiKeyId") REFERENCES "DevApiKey"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CronExecution" ADD CONSTRAINT "CronExecution_cronJobId_fkey" FOREIGN KEY ("cronJobId") REFERENCES "CronJob"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TimerAlert" ADD CONSTRAINT "TimerAlert_scheduledOpId_fkey" FOREIGN KEY ("scheduledOpId") REFERENCES "ScheduledOperation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PoolPrice" ADD CONSTRAINT "PoolPrice_poolId_fkey" FOREIGN KEY ("poolId") REFERENCES "DexPool"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PriceDeviation" ADD CONSTRAINT "PriceDeviation_poolIdA_fkey" FOREIGN KEY ("poolIdA") REFERENCES "DexPool"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PriceDeviation" ADD CONSTRAINT "PriceDeviation_poolIdB_fkey" FOREIGN KEY ("poolIdB") REFERENCES "DexPool"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ArbitrageOpportunity" ADD CONSTRAINT "ArbitrageOpportunity_buyPoolId_fkey" FOREIGN KEY ("buyPoolId") REFERENCES "DexPool"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ArbitrageOpportunity" ADD CONSTRAINT "ArbitrageOpportunity_sellPoolId_fkey" FOREIGN KEY ("sellPoolId") REFERENCES "DexPool"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MevOpportunityScore" ADD CONSTRAINT "MevOpportunityScore_opportunityId_fkey" FOREIGN KEY ("opportunityId") REFERENCES "ArbitrageOpportunity"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ArbitrageExecution" ADD CONSTRAINT "ArbitrageExecution_opportunityId_fkey" FOREIGN KEY ("opportunityId") REFERENCES "ArbitrageOpportunity"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FeatureValue" ADD CONSTRAINT "FeatureValue_featureId_fkey" FOREIGN KEY ("featureId") REFERENCES "FeatureDefinition"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Attestation" ADD CONSTRAINT "Attestation_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Endorsement" ADD CONSTRAINT "Endorsement_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExportJob" ADD CONSTRAINT "ExportJob_developerId_fkey" FOREIGN KEY ("developerId") REFERENCES "Developer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GovernanceVote" ADD CONSTRAINT "GovernanceVote_proposalId_fkey" FOREIGN KEY ("proposalId") REFERENCES "GovernanceProposal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LinkedIdentity" ADD CONSTRAINT "LinkedIdentity_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReputationBadge" ADD CONSTRAINT "ReputationBadge_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReputationDisputeVote" ADD CONSTRAINT "ReputationDisputeVote_disputeId_fkey" FOREIGN KEY ("disputeId") REFERENCES "ReputationDispute"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReputationTrustConnection" ADD CONSTRAINT "ReputationTrustConnection_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReputationSignal" ADD CONSTRAINT "ReputationSignal_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "VerifiableCredential" ADD CONSTRAINT "VerifiableCredential_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "ReputationProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WebhookDelivery" ADD CONSTRAINT "WebhookDelivery_subscriptionId_fkey" FOREIGN KEY ("subscriptionId") REFERENCES "WebhookSubscription"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nl_query_contexts" ADD CONSTRAINT "nl_query_contexts_query_id_fkey" FOREIGN KEY ("query_id") REFERENCES "nl_queries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "saved_queries" ADD CONSTRAINT "saved_queries_query_id_fkey" FOREIGN KEY ("query_id") REFERENCES "nl_queries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nl_report_history" ADD CONSTRAINT "nl_report_history_report_id_fkey" FOREIGN KEY ("report_id") REFERENCES "nl_reports"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "archival_epochs" ADD CONSTRAINT "archival_epochs_nodeId_fkey" FOREIGN KEY ("nodeId") REFERENCES "archival_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "storage_challenges" ADD CONSTRAINT "storage_challenges_epochId_fkey" FOREIGN KEY ("epochId") REFERENCES "archival_epochs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "storage_challenges" ADD CONSTRAINT "storage_challenges_nodeId_fkey" FOREIGN KEY ("nodeId") REFERENCES "archival_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "data_retrievals" ADD CONSTRAINT "data_retrievals_epochId_fkey" FOREIGN KEY ("epochId") REFERENCES "archival_epochs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "data_retrievals" ADD CONSTRAINT "data_retrievals_nodeId_fkey" FOREIGN KEY ("nodeId") REFERENCES "archival_nodes"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sla_offers" ADD CONSTRAINT "sla_offers_nodeId_fkey" FOREIGN KEY ("nodeId") REFERENCES "archival_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sla_acceptances" ADD CONSTRAINT "sla_acceptances_offerId_fkey" FOREIGN KEY ("offerId") REFERENCES "sla_offers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "archival_slashes" ADD CONSTRAINT "archival_slashes_nodeId_fkey" FOREIGN KEY ("nodeId") REFERENCES "archival_nodes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "archival_slashes" ADD CONSTRAINT "archival_slashes_challengeId_fkey" FOREIGN KEY ("challengeId") REFERENCES "storage_challenges"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "archival_appeals" ADD CONSTRAINT "archival_appeals_slashId_fkey" FOREIGN KEY ("slashId") REFERENCES "archival_slashes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NftItem" ADD CONSTRAINT "NftItem_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "NftCollection"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NftTrait" ADD CONSTRAINT "NftTrait_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "NftCollection"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NftSale" ADD CONSTRAINT "NftSale_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "NftCollection"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NftListing" ADD CONSTRAINT "NftListing_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "NftCollection"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NftCollectionStats" ADD CONSTRAINT "NftCollectionStats_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "NftCollection"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NftActivity" ADD CONSTRAINT "NftActivity_collectionId_fkey" FOREIGN KEY ("collectionId") REFERENCES "NftCollection"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_sessions" ADD CONSTRAINT "auth_sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "wallet_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_events" ADD CONSTRAINT "auth_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "wallet_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_webhooks" ADD CONSTRAINT "auth_webhooks_userId_fkey" FOREIGN KEY ("userId") REFERENCES "wallet_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

