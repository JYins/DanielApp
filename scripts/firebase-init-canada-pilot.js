#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const auth = require("./firebase-cli-auth");

const CONFIRM_FLAG = "--confirm-canada-pilot";
const DEFAULT_MANIFEST = "config/canada-pilot.manifest.json";
const EXPECTED_PILOT_ID = "canada-four-church-pilot";
const EXPECTED_BRANCHES = [
  { id: "canada-toronto-church", code: "CA-TORONTO", name: { zh: "多伦多教会", en: "Toronto Church", ko: "토론토 교회" } },
  { id: "canada-vancouver-church", code: "CA-VANCOUVER", name: { zh: "温哥华教会", en: "Vancouver Church", ko: "밴쿠버 교회" } },
  { id: "canada-calgary-church", code: "CA-CALGARY", name: { zh: "卡尔加里教会", en: "Calgary Church", ko: "캘거리 교회" } },
  { id: "canada-montreal-church", code: "CA-MONTREAL", name: { zh: "蒙特利尔教会", en: "Montreal Church", ko: "몬트리올 교회" } }
];
const EXPECTED_BRANCH_IDS = EXPECTED_BRANCHES.map(branch => branch.id);

function argValue(name, argv = process.argv) {
  const index = argv.indexOf(name);
  return index >= 0 ? argv[index + 1] : undefined;
}

function usage() {
  console.log(`Usage:
  node scripts/firebase-init-canada-pilot.js
  node scripts/firebase-init-canada-pilot.js --manifest config/canada-pilot.local.json --project daniel1-ca1e7
  node scripts/firebase-init-canada-pilot.js --manifest config/canada-pilot.local.json --project daniel1-ca1e7 ${CONFIRM_FLAG}

Default mode is an offline dry run. Copy ${DEFAULT_MANIFEST} to the ignored
config/canada-pilot.local.json and replace every null before requesting a production write.
The confirmation flag creates only the manifest-scoped region, branch, and branchConnect documents.`);
}

function readManifest(filePath) {
  const absolutePath = path.resolve(filePath);
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Manifest not found: ${absolutePath}`);
  }
  return JSON.parse(fs.readFileSync(absolutePath, "utf8"));
}

function isLocalizedName(value) {
  return value && ["zh", "en", "ko"].every(language =>
    typeof value[language] === "string" && value[language].trim().length > 0
  );
}

function matchesLocalizedName(value, expected) {
  return isLocalizedName(value) && ["zh", "en", "ko"].every(language => value[language] === expected[language]);
}

function missingOperationalFields(manifest) {
  const missing = [];
  for (const branch of manifest.branches || []) {
    for (const field of ["city", "timezone", "branchAdminEmail", "kakaoURL"]) {
      if (typeof branch[field] !== "string" || branch[field].trim() === "") {
        missing.push(`${branch.id || "(missing branch id)"}.${field}`);
      }
    }
  }
  return missing;
}

function assertProductionReady(manifest, manifestPath) {
  if (manifest.template === true || path.resolve(manifestPath) === path.resolve(DEFAULT_MANIFEST)) {
    throw new Error("Refusing production confirmation with the tracked template manifest. Use config/canada-pilot.local.json.");
  }
  const missing = missingOperationalFields(manifest);
  if (missing.length) {
    throw new Error(`Refusing production confirmation; fill these values first:\n- ${missing.join("\n- ")}`);
  }
}

function validateManifest(manifest) {
  const errors = [];
  if (manifest.schemaVersion !== 1) errors.push("schemaVersion must be 1");
  if (manifest.pilotId !== EXPECTED_PILOT_ID) errors.push(`pilotId must be ${EXPECTED_PILOT_ID}`);
  if (manifest.organizationId !== "daniel-branch-church") {
    errors.push("organizationId must be daniel-branch-church");
  }
  if (!manifest.region || manifest.region.id !== "canada-pilot" || manifest.region.code !== "CA-PILOT" ||
      manifest.region.country !== "Canada" || !Number.isInteger(manifest.region.sortOrder) ||
      !matchesLocalizedName(manifest.region.name, { zh: "加拿大", en: "Canada", ko: "캐나다" })) {
    errors.push("region must preserve the tracked Canada pilot id, code, names, country, and integer sortOrder");
  }

  const branches = Array.isArray(manifest.branches) ? manifest.branches : [];
  const branchIds = branches.map(branch => branch.id);
  if (branches.length !== EXPECTED_BRANCH_IDS.length ||
      [...branchIds].sort().join("|") !== [...EXPECTED_BRANCH_IDS].sort().join("|")) {
    errors.push(`branches must contain exactly: ${EXPECTED_BRANCH_IDS.join(", ")}`);
  }
  if (new Set(branchIds).size !== branchIds.length) errors.push("branch ids must be unique");
  if (new Set(branches.map(branch => branch.code)).size !== branches.length) {
    errors.push("branch codes must be unique");
  }

  for (const branch of branches) {
    if (!isLocalizedName(branch.name)) errors.push(`${branch.id || "branch"}.name must include zh/en/ko`);
    if (typeof branch.code !== "string" || !branch.code.trim()) errors.push(`${branch.id || "branch"}.code is required`);
    if (!Number.isInteger(branch.sortOrder)) errors.push(`${branch.id || "branch"}.sortOrder must be an integer`);
    const expected = EXPECTED_BRANCHES.find(item => item.id === branch.id);
    if (expected && (branch.code !== expected.code || !matchesLocalizedName(branch.name, expected.name))) {
      errors.push(`${branch.id} must preserve its tracked code and zh/en/ko names`);
    }
    if (typeof branch.timezone === "string" && branch.timezone) {
      try {
        new Intl.DateTimeFormat("en-CA", { timeZone: branch.timezone }).format();
      } catch {
        errors.push(`${branch.id}.timezone is not a valid IANA timezone`);
      }
    }
    if (typeof branch.branchAdminEmail === "string" && branch.branchAdminEmail &&
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(branch.branchAdminEmail)) {
      errors.push(`${branch.id}.branchAdminEmail is not a valid email address`);
    }
    if (typeof branch.kakaoURL === "string" && branch.kakaoURL) {
      try {
        const url = new URL(branch.kakaoURL);
        if (url.protocol !== "https:" || url.hostname !== "open.kakao.com") {
          errors.push(`${branch.id}.kakaoURL must be an https://open.kakao.com link`);
        }
      } catch {
        errors.push(`${branch.id}.kakaoURL is not a valid URL`);
      }
    }
  }

  if (errors.length) throw new Error(`Invalid Canada pilot manifest:\n- ${errors.join("\n- ")}`);
  return manifest;
}

function buildPlan(manifest, now = new Date().toISOString()) {
  const timestamp = { timestampValue: now };
  const region = {
    id: manifest.region.id,
    orgId: manifest.organizationId,
    code: manifest.region.code,
    name: manifest.region.name,
    country: manifest.region.country,
    isActive: true,
    sortOrder: manifest.region.sortOrder,
    createdAt: timestamp,
    updatedAt: timestamp
  };
  const branches = manifest.branches.map(branch => ({
    id: branch.id,
    orgId: manifest.organizationId,
    regionId: manifest.region.id,
    regionName: manifest.region.name,
    code: branch.code,
    name: branch.name,
    country: manifest.region.country,
    city: branch.city,
    timezone: branch.timezone,
    isActive: true,
    sortOrder: branch.sortOrder,
    createdAt: timestamp,
    updatedAt: timestamp
  }));
  const branchConnect = manifest.branches.map(branch => ({
    documentId: branch.id,
    data: {
      branchId: branch.id,
      groupNameZh: branch.name.zh,
      groupNameEn: branch.name.en,
      groupNameKo: branch.name.ko,
      kakaoURL: branch.kakaoURL,
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp
    }
  }));

  return { region, branches, branchConnect };
}

function printPlan(manifest, plan, manifestPath, projectId) {
  console.log(`Manifest: ${path.resolve(manifestPath)}`);
  console.log(`Project: ${projectId}`);
  console.log(`Pilot: ${manifest.pilotId}`);
  console.log(`Organization (read-only prerequisite): ${manifest.organizationId}`);
  console.log(`Region create-only: ${plan.region.id} (${plan.region.name.en})`);
  console.log("Branch and branchConnect documents create-only:");
  for (const branch of manifest.branches) {
    console.log(`- ${branch.id}: ${branch.name.zh} / ${branch.name.en} / ${branch.name.ko}`);
    console.log(`  city=${branch.city || "<REQUIRED>"} timezone=${branch.timezone || "<REQUIRED>"}`);
    console.log(`  branchAdminEmail=${branch.branchAdminEmail || "<REQUIRED>"}`);
    console.log(`  kakaoURL=${branch.kakaoURL || "<REQUIRED>"}`);
  }
  console.log("Unrelated users, memberships, organizations, regions, and branches will not be changed.");
  console.log("Branch-admin assignment and plaintext invite-token creation are separate Admin Portal steps.");
}

function firestoreValue(value) {
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (value && typeof value === "object" && "timestampValue" in value) return value;
  if (value && typeof value === "object") {
    return { mapValue: { fields: firestoreFields(value) } };
  }
  throw new Error(`Unsupported or missing Firestore value: ${value}`);
}

function firestoreFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]));
}

async function accessToken() {
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error("No Firebase CLI refresh token found. Run firebase login --reauth first.");
  }
  const tokenData = await auth.getAccessToken(account.tokens.refresh_token, []);
  return tokenData.access_token;
}

async function firestoreFetch(projectId, firestorePath, options = {}) {
  const token = await accessToken();
  const response = await fetch(`https://firestore.googleapis.com/v1/${firestorePath}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${response.status} ${body.error?.status || ""}: ${body.error?.message || "Firestore request failed"}`);
  }
  return body;
}

async function assertOrganizationExists(projectId, organizationId) {
  await firestoreFetch(
    projectId,
    `projects/${projectId}/databases/(default)/documents/organizations/${organizationId}`
  );
}

async function assertTargetsDoNotExist(projectId, plan) {
  const targets = [
    ["regions", plan.region.id],
    ...plan.branches.map(branch => ["branches", branch.id]),
    ...plan.branchConnect.map(connect => ["branchConnect", connect.documentId])
  ];
  const token = await accessToken();
  const conflicts = [];
  for (const [collectionId, documentId] of targets) {
    const response = await fetch(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${collectionId}/${documentId}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    if (response.ok) conflicts.push(`${collectionId}/${documentId}`);
    else if (response.status !== 404) {
      const body = await response.json().catch(() => ({}));
      throw new Error(`${response.status}: ${body.error?.message || "Firestore preflight failed"}`);
    }
  }
  if (conflicts.length) {
    throw new Error(`Refusing to overwrite existing documents:\n- ${conflicts.join("\n- ")}`);
  }
}

function createOnlyWrites(projectId, plan) {
  const documents = [
    ["regions", plan.region],
    ...plan.branches.map(branch => ["branches", branch]),
    ...plan.branchConnect.map(connect => ["branchConnect", { id: connect.documentId, ...connect.data }])
  ];
  return documents.map(([collectionId, data]) => ({
    update: {
      name: `projects/${projectId}/databases/(default)/documents/${collectionId}/${data.id}`,
      fields: firestoreFields(Object.fromEntries(Object.entries(data).filter(([key]) => key !== "id" || collectionId !== "branchConnect")))
    },
    currentDocument: { exists: false }
  }));
}

async function main(argv = process.argv) {
  const args = new Set(argv.slice(2));
  if (args.has("--help") || args.has("-h")) {
    usage();
    return;
  }

  const isConfirmed = args.has(CONFIRM_FLAG);
  if (isConfirmed && (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
    throw new Error("Refusing production confirmation while Firebase emulator environment variables are set.");
  }

  const manifestPath = argValue("--manifest", argv) || DEFAULT_MANIFEST;
  const projectId = argValue("--project", argv) || process.env.GCLOUD_PROJECT || "daniel1-ca1e7";
  const manifest = validateManifest(readManifest(manifestPath));
  const plan = buildPlan(manifest);
  const missing = missingOperationalFields(manifest);
  printPlan(manifest, plan, manifestPath, projectId);

  if (!isConfirmed) {
    if (missing.length) console.log(`Dry run incomplete; ${missing.length} operational values remain required.`);
    console.log(`Dry run only. Production writes require a completed local manifest and ${CONFIRM_FLAG}.`);
    return;
  }
  assertProductionReady(manifest, manifestPath);

  await assertOrganizationExists(projectId, manifest.organizationId);
  await assertTargetsDoNotExist(projectId, plan);
  await firestoreFetch(
    projectId,
    `projects/${projectId}/databases/(default)/documents:commit`,
    { method: "POST", body: JSON.stringify({ writes: createOnlyWrites(projectId, plan) }) }
  );
  console.log("Canada pilot branch documents created. No users, memberships, claims, or invite tokens were changed.");
  console.log("Next: assign each listed email as branch_admin in Admin > Members, then create one token in Admin > Invite Token.");
}

if (require.main === module) {
  main().catch(error => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = {
  EXPECTED_BRANCH_IDS,
  assertProductionReady,
  buildPlan,
  createOnlyWrites,
  missingOperationalFields,
  readManifest,
  validateManifest
};
