#!/usr/bin/env node

const fs = require("fs");
const { execFileSync } = require("child_process");
const auth = require("./firebase-cli-auth");

const ORG_ID = "daniel-branch-church";
const args = new Set(process.argv.slice(2));
const isConfirmed = args.has("--confirm-branch-system");
const shouldCheckOnly = args.has("--check");
const projectArgIndex = process.argv.indexOf("--project");

function defaultProjectId() {
  if (!fs.existsSync("GoogleService-Info.plist")) {
    return "daniel1-ca1e7";
  }

  try {
    return execFileSync(
      "/usr/libexec/PlistBuddy",
      ["-c", "Print :PROJECT_ID", "GoogleService-Info.plist"],
      { encoding: "utf8" }
    ).trim();
  } catch {
    return "daniel1-ca1e7";
  }
}

const projectId =
  projectArgIndex >= 0 && process.argv[projectArgIndex + 1]
    ? process.argv[projectArgIndex + 1]
    : process.env.GCLOUD_PROJECT || defaultProjectId();

if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error("Refusing to run: emulator env vars are set, but this script writes production Firestore.");
  process.exit(1);
}

function slugify(value, fallback) {
  const slug = String(value || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || fallback;
}

function localized(value) {
  const text = String(value || "").trim() || "未分配";
  return { zh: text, en: text, ko: text };
}

function valueFromField(field) {
  if (!field) return undefined;
  if ("stringValue" in field) return field.stringValue;
  if ("booleanValue" in field) return field.booleanValue;
  if ("integerValue" in field) return Number(field.integerValue);
  if ("timestampValue" in field) return field.timestampValue;
  return undefined;
}

function firestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: "NULL_VALUE" };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (value && typeof value === "object" && "timestampValue" in value) return value;
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(Object.entries(value).map(([key, nested]) => [key, firestoreValue(nested)]))
      }
    };
  }
  throw new Error(`Unsupported Firestore value: ${value}`);
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

async function firestoreFetch(path, options = {}) {
  const token = await accessToken();
  const response = await fetch(`https://firestore.googleapis.com/v1/${path}`, {
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

async function readUsers() {
  const users = [];
  let pageToken;

  do {
    const query = new URLSearchParams({ pageSize: "300" });
    if (pageToken) query.set("pageToken", pageToken);
    const result = await firestoreFetch(
      `projects/${projectId}/databases/(default)/documents/users?${query.toString()}`
    );
    for (const document of result.documents || []) {
      const id = document.name.split("/").pop();
      const fields = document.fields || {};
      users.push({
        id,
        role: valueFromField(fields.role),
        accessRole: valueFromField(fields.accessRole),
        isApproved: valueFromField(fields.isApproved) === true,
        churchCountry: valueFromField(fields.churchCountry),
        churchName: valueFromField(fields.churchName),
        regionId: valueFromField(fields.regionId),
        branchId: valueFromField(fields.branchId)
      });
    }
    pageToken = result.nextPageToken;
  } while (pageToken);

  return users;
}

function buildPlan(users) {
  const now = { timestampValue: new Date().toISOString() };
  const regions = new Map();
  const branches = new Map();
  const memberships = [];
  const userUpdates = [];

  for (const user of users) {
    const country = user.churchCountry || "Unassigned Region";
    const church = user.churchName || "Unassigned Branch";
    const regionId = user.regionId || slugify(country, "unassigned-region");
    const branchId = user.branchId || `${regionId}-${slugify(church, "unassigned-branch")}`;
    const branchName = church;
    const regionName = country;
    const currentRole = user.accessRole || user.role || "member";
    const accessRole = currentRole === "admin" ? "global_admin" : currentRole;
    const role = currentRole === "global_admin" ? "admin" : currentRole;
    const membershipStatus = user.isApproved ? "active" : "pending";

    if (!regions.has(regionId)) {
      regions.set(regionId, {
        id: regionId,
        orgId: ORG_ID,
        code: regionId,
        name: localized(regionName),
        country: regionName,
        isActive: true,
        sortOrder: regions.size + 10,
        createdAt: now,
        updatedAt: now
      });
    }

    if (!branches.has(branchId)) {
      branches.set(branchId, {
        id: branchId,
        orgId: ORG_ID,
        regionId,
        regionName: localized(regionName),
        code: branchId,
        name: localized(branchName),
        country: regionName,
        city: "",
        timezone: "America/Toronto",
        isActive: true,
        sortOrder: branches.size + 10,
        createdAt: now,
        updatedAt: now
      });
    }

    userUpdates.push({
      userId: user.id,
      fields: {
        orgId: ORG_ID,
        regionId,
        regionName,
        branchId,
        branchName,
        role,
        accessRole,
        membershipStatus,
        updatedAt: now
      }
    });

    memberships.push({
      id: `${branchId}_${user.id}`,
      userId: user.id,
      orgId: ORG_ID,
      regionId,
      branchId,
      role,
      accessRole,
      status: membershipStatus,
      createdAt: now,
      updatedAt: now
    });
  }

  return {
    organization: {
      id: ORG_ID,
      name: {
        zh: "Daniel 分堂教会",
        en: "Daniel Branch Church",
        ko: "Daniel 지교회"
      },
      isActive: true,
      sortOrder: 10,
      createdAt: now,
      updatedAt: now
    },
    regions: [...regions.values()],
    branches: [...branches.values()],
    memberships,
    userUpdates
  };
}

function printPlan(plan, users) {
  console.log(`Project: ${projectId}`);
  console.log(`Users scanned: ${users.length}`);
  console.log(`Regions to upsert: ${plan.regions.length}`);
  for (const region of plan.regions) {
    console.log(`- region ${region.id}: ${region.name.zh}`);
  }
  console.log(`Branches to upsert: ${plan.branches.length}`);
  for (const branch of plan.branches) {
    console.log(`- branch ${branch.id}: ${branch.name.zh} (${branch.regionId})`);
  }
  console.log(`Membership documents to upsert: ${plan.memberships.length}`);
  console.log(`User profile documents to patch: ${plan.userUpdates.length}`);
}

function writesForPlan(plan) {
  const writes = [
    {
      update: {
        name: `projects/${projectId}/databases/(default)/documents/organizations/${ORG_ID}`,
        fields: firestoreFields(plan.organization)
      }
    },
    ...plan.regions.map(region => ({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/regions/${region.id}`,
        fields: firestoreFields(region)
      }
    })),
    ...plan.branches.map(branch => ({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/branches/${branch.id}`,
        fields: firestoreFields(branch)
      }
    })),
    ...plan.memberships.map(membership => ({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/branchMemberships/${membership.id}`,
        fields: firestoreFields(membership)
      }
    })),
    ...plan.userUpdates.map(update => ({
      update: {
        name: `projects/${projectId}/databases/(default)/documents/users/${update.userId}`,
        fields: firestoreFields(update.fields)
      },
      updateMask: {
        fieldPaths: Object.keys(update.fields)
      },
      currentDocument: {
        exists: true
      }
    }))
  ];

  return writes;
}

async function commitBatches(writes) {
  for (let index = 0; index < writes.length; index += 400) {
    const batch = writes.slice(index, index + 400);
    await firestoreFetch(`projects/${projectId}/databases/(default)/documents:commit`, {
      method: "POST",
      body: JSON.stringify({ writes: batch })
    });
  }
}

async function collectionCount(collectionId) {
  const result = await firestoreFetch(
    `projects/${projectId}/databases/(default)/documents/${collectionId}?pageSize=1000`
  );
  return result.documents?.length || 0;
}

async function checkStatus() {
  const [orgCount, regionCount, branchCount, membershipCount, userCount] = await Promise.all([
    collectionCount("organizations"),
    collectionCount("regions"),
    collectionCount("branches"),
    collectionCount("branchMemberships"),
    collectionCount("users")
  ]);
  console.log(`Project: ${projectId}`);
  console.log(`organizations: ${orgCount}`);
  console.log(`regions: ${regionCount}`);
  console.log(`branches: ${branchCount}`);
  console.log(`branchMemberships: ${membershipCount}`);
  console.log(`users: ${userCount}`);
}

async function main() {
  if (shouldCheckOnly) {
    await checkStatus();
    return;
  }

  const users = await readUsers();
  const plan = buildPlan(users);
  printPlan(plan, users);

  if (!isConfirmed) {
    console.log("Dry run only. Re-run with --confirm-branch-system to write production Firestore.");
    return;
  }

  await commitBatches(writesForPlan(plan));
  console.log("Branch system seed completed.");
  await checkStatus();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
