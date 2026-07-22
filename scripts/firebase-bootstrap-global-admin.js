#!/usr/bin/env node

const fs = require("fs");
const { execFileSync } = require("child_process");
const auth = require("./firebase-cli-auth");

const ORG_ID = "daniel-branch-church";
const CONFIRM_FLAG = "--confirm-global-admin";

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const args = new Set(process.argv.slice(2));
const projectId = argValue("--project") || process.env.GCLOUD_PROJECT || defaultProjectId();
const targetUid = argValue("--uid");
const targetEmail = argValue("--email");
const isConfirmed = args.has(CONFIRM_FLAG);
const shouldCheck = args.has("--check");
const shouldList = args.has("--list");
const shouldHelp = args.has("--help") || args.has("-h");

if (!shouldHelp && (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
  console.error("Refusing to run: emulator env vars are set, but this script targets production Firebase.");
  process.exit(1);
}

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

function usage() {
  console.log(`Usage:
  node scripts/firebase-bootstrap-global-admin.js --project ${projectId} --list
  node scripts/firebase-bootstrap-global-admin.js --project ${projectId} --check
  node scripts/firebase-bootstrap-global-admin.js --project ${projectId} --email user@example.com
  node scripts/firebase-bootstrap-global-admin.js --project ${projectId} --uid firebaseAuthUid
  node scripts/firebase-bootstrap-global-admin.js --project ${projectId} --email user@example.com ${CONFIRM_FLAG}

Default mode is dry-run. ${CONFIRM_FLAG} is required before production writes.`);
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

async function authedFetch(url, options = {}) {
  const token = await accessToken();
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${response.status} ${body.error?.status || ""}: ${body.error?.message || "Request failed"}`);
  }
  return body;
}

async function firestoreFetch(path, options = {}) {
  return authedFetch(`https://firestore.googleapis.com/v1/${path}`, options);
}

async function identityFetch(method, body) {
  return authedFetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:${method}`,
    {
      method: "POST",
      body: JSON.stringify(body)
    }
  );
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
        email: valueFromField(fields.email),
        name: valueFromField(fields.name),
        role: valueFromField(fields.role),
        accessRole: valueFromField(fields.accessRole),
        isApproved: valueFromField(fields.isApproved) === true,
        churchCountry: valueFromField(fields.churchCountry),
        churchName: valueFromField(fields.churchName),
        regionId: valueFromField(fields.regionId),
        regionName: valueFromField(fields.regionName),
        branchId: valueFromField(fields.branchId),
        branchName: valueFromField(fields.branchName),
        membershipStatus: valueFromField(fields.membershipStatus)
      });
    }
    pageToken = result.nextPageToken;
  } while (pageToken);

  return users;
}

function isGlobalAdmin(user) {
  return user.role === "admin" || user.accessRole === "global_admin";
}

function printUser(user) {
  console.log([
    user.id,
    user.email || "(no email)",
    user.name || "(no name)",
    `approved=${user.isApproved}`,
    `role=${user.role || "(none)"}`,
    `accessRole=${user.accessRole || "(none)"}`,
    `region=${user.regionId || user.churchCountry || "(none)"}`,
    `branch=${user.branchId || user.churchName || "(none)"}`
  ].join(" | "));
}

async function lookupAuthUser(uid, email) {
  const body = uid ? { localId: [uid] } : { email: [email] };
  const result = await identityFetch("lookup", body);
  return result.users?.[0];
}

function parseCustomClaims(authUser) {
  if (!authUser?.customAttributes) return {};
  try {
    return JSON.parse(authUser.customAttributes);
  } catch {
    return {};
  }
}

function buildPlan(user, authUser) {
  const now = { timestampValue: new Date().toISOString() };
  const regionName = user.regionName || user.churchCountry || "Unassigned Region";
  const branchName = user.branchName || user.churchName || "Unassigned Branch";
  const regionId = user.regionId || slugify(regionName, "unassigned-region");
  const branchId = user.branchId || `${regionId}-${slugify(branchName, "unassigned-branch")}`;
  const baseClaims = parseCustomClaims(authUser);
  const claims = {
    ...baseClaims,
    role: "admin",
    accessRole: "global_admin",
    orgId: ORG_ID,
    regionId,
    branchId,
    membershipStatus: "active",
    isApproved: true
  };

  return {
    userId: user.id,
    email: user.email || authUser?.email,
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
    region: {
      id: regionId,
      orgId: ORG_ID,
      code: regionId,
      name: localized(regionName),
      country: regionName,
      isActive: true,
      sortOrder: 10,
      createdAt: now,
      updatedAt: now
    },
    branch: {
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
      sortOrder: 10,
      createdAt: now,
      updatedAt: now
    },
    membership: {
      id: `${branchId}_${user.id}`,
      userId: user.id,
      orgId: ORG_ID,
      regionId,
      branchId,
      role: "admin",
      accessRole: "global_admin",
      status: "active",
      createdAt: now,
      updatedAt: now
    },
    userFields: {
      orgId: ORG_ID,
      regionId,
      regionName,
      branchId,
      branchName,
      role: "admin",
      accessRole: "global_admin",
      isApproved: true,
      membershipStatus: "active",
      approvedAt: now,
      approvedBy: "firebase-bootstrap-global-admin",
      updatedAt: now
    },
    claims
  };
}

function printPlan(plan, authUser) {
  const existingClaims = parseCustomClaims(authUser);
  console.log(`Project: ${projectId}`);
  console.log(`Target user: ${plan.userId} (${plan.email || "no email"})`);
  console.log(`Auth user found: ${authUser ? "yes" : "no"}`);
  console.log(`Existing Auth custom claims: ${JSON.stringify(existingClaims)}`);
  console.log(`Organization upsert: ${plan.organization.id}`);
  console.log(`Region upsert: ${plan.region.id} (${plan.region.name.zh})`);
  console.log(`Branch upsert: ${plan.branch.id} (${plan.branch.name.zh})`);
  console.log(`Membership upsert: ${plan.membership.id}`);
  console.log("User patch fields:");
  for (const [key, value] of Object.entries(plan.userFields)) {
    if (typeof value === "object" && value.timestampValue) {
      console.log(`- ${key}: ${value.timestampValue}`);
    } else {
      console.log(`- ${key}: ${value}`);
    }
  }
  console.log(`Auth custom claims: ${JSON.stringify(plan.claims)}`);
}

function writesForPlan(plan) {
  const document = collection => `projects/${projectId}/databases/(default)/documents/${collection}`;
  return [
    {
      update: {
        name: `${document("organizations")}/${plan.organization.id}`,
        fields: firestoreFields(plan.organization)
      }
    },
    {
      update: {
        name: `${document("regions")}/${plan.region.id}`,
        fields: firestoreFields(plan.region)
      }
    },
    {
      update: {
        name: `${document("branches")}/${plan.branch.id}`,
        fields: firestoreFields(plan.branch)
      }
    },
    {
      update: {
        name: `${document("branchMemberships")}/${plan.membership.id}`,
        fields: firestoreFields(plan.membership)
      }
    },
    {
      update: {
        name: `${document("users")}/${plan.userId}`,
        fields: firestoreFields(plan.userFields)
      },
      updateMask: {
        fieldPaths: Object.keys(plan.userFields)
      },
      currentDocument: {
        exists: true
      }
    }
  ];
}

async function commitPlan(plan) {
  await firestoreFetch(`projects/${projectId}/databases/(default)/documents:commit`, {
    method: "POST",
    body: JSON.stringify({ writes: writesForPlan(plan) })
  });
  await identityFetch("update", {
    localId: plan.userId,
    customAttributes: JSON.stringify(plan.claims)
  });
}

async function main() {
  if (shouldHelp) {
    usage();
    return;
  }

  const users = await readUsers();

  if (shouldList) {
    console.log(`Project: ${projectId}`);
    console.log(`Users: ${users.length}`);
    users.forEach(printUser);
    return;
  }

  if (shouldCheck) {
    const globalAdmins = users.filter(isGlobalAdmin);
    console.log(`Project: ${projectId}`);
    console.log(`Global admin candidates: ${globalAdmins.length}`);
    globalAdmins.forEach(printUser);
    return;
  }

  if (!targetUid && !targetEmail) {
    usage();
    process.exit(1);
  }

  const target = users.find(user => {
    if (targetUid && user.id === targetUid) return true;
    if (targetEmail && user.email?.toLowerCase() === targetEmail.toLowerCase()) return true;
    return false;
  });

  if (!target) {
    throw new Error("Target user was not found in Firestore users collection. Create the user profile first.");
  }

  const authUser = await lookupAuthUser(target.id, target.email || targetEmail);
  if (!authUser) {
    throw new Error("Target user was not found in Firebase Auth. Firestore and Auth UID must match before bootstrapping.");
  }

  const plan = buildPlan(target, authUser);
  printPlan(plan, authUser);

  if (!isConfirmed) {
    console.log(`Dry run only. Re-run with ${CONFIRM_FLAG} to write production Firestore and Auth custom claims.`);
    return;
  }

  await commitPlan(plan);
  console.log("Global admin bootstrap completed.");
}

main().catch(error => {
  console.error(error.message);
  process.exit(1);
});
