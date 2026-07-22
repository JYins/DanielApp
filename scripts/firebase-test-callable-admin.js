#!/usr/bin/env node

const { createRequire } = require("node:module");
const path = require("node:path");
const functionsRequire = createRequire(path.resolve(__dirname, "../functions/package.json"));
const { initializeApp } = functionsRequire("firebase-admin/app");
const { getFirestore } = functionsRequire("firebase-admin/firestore");

const projectId = process.env.GCLOUD_PROJECT || "daniel1-ca1e7";
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;

if (!authHost) {
  console.error("Refusing to run: FIREBASE_AUTH_EMULATOR_HOST is not set.");
  process.exit(1);
}

if (!firestoreHost) {
  console.error("Refusing to run: FIRESTORE_EMULATOR_HOST is not set.");
  process.exit(1);
}

initializeApp({ projectId });
const db = getFirestore();

async function signIn(email, password) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password,
        returnSecureToken: true
      })
    }
  );
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`Auth sign-in failed: ${JSON.stringify(body)}`);
  }
  return body.idToken;
}

async function callSetUserAccess(idToken, payload) {
  const response = await fetch(
    `http://${functionHost}/${projectId}/us-central1/setUserAccessAdmin`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${idToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ data: payload })
    }
  );
  const body = await response.json();
  if (!response.ok || body.error) {
    throw new Error(`Callable failed: ${JSON.stringify(body)}`);
  }
  return body.result;
}

async function expectCallableFailure(idToken, payload, expectedStatus) {
  const response = await fetch(
    `http://${functionHost}/${projectId}/us-central1/setUserAccessAdmin`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${idToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ data: payload })
    }
  );
  const body = await response.json();
  const status = body?.error?.status || body?.error?.message;
  if (response.ok && !body.error) {
    throw new Error(`Expected callable failure, got success: ${JSON.stringify(body)}`);
  }
  if (expectedStatus && status !== expectedStatus) {
    throw new Error(`Expected callable failure ${expectedStatus}, got ${JSON.stringify(body)}`);
  }
}

function decodeJwtPayload(idToken) {
  const payload = idToken.split(".")[1];
  return JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
}

async function main() {
  const adminToken = await signIn("admin@example.test", "password123");
  const result = await callSetUserAccess(adminToken, {
    uid: "test-approved-user",
    isApproved: true,
    branchId: "canada-other-test-church",
    accessRole: "branch_admin",
    membershipStatus: "active"
  });

  const userDoc = await db.collection("users").doc("test-approved-user").get();
  const membershipDoc = await db
    .collection("branchMemberships")
    .doc("canada-other-test-church_test-approved-user")
    .get();

  const user = userDoc.data();
  if (user?.branchId !== "canada-other-test-church") {
    throw new Error(`Expected user branchId to update, got ${user?.branchId}`);
  }
  if (user?.accessRole !== "branch_admin") {
    throw new Error(`Expected user accessRole branch_admin, got ${user?.accessRole}`);
  }
  if (!membershipDoc.exists) {
    throw new Error("Expected updated branch membership to exist.");
  }

  const memberToken = await signIn("approved@example.test", "password123");
  const claims = decodeJwtPayload(memberToken);
  if (claims.accessRole !== "branch_admin") {
    throw new Error(`Expected custom claim accessRole branch_admin, got ${claims.accessRole}`);
  }
  if (claims.branchId !== "canada-other-test-church") {
    throw new Error(`Expected custom claim branchId canada-other-test-church, got ${claims.branchId}`);
  }

  const branchAdminToken = await signIn("branch-admin@example.test", "password123");
  await callSetUserAccess(branchAdminToken, {
    uid: "test-pending-branch-user",
    isApproved: true,
    branchId: "canada-daniel-test-church",
    accessRole: "member",
    membershipStatus: "active"
  });
  await expectCallableFailure(branchAdminToken, {
    uid: "test-other-user",
    isApproved: true,
    branchId: "canada-other-test-church",
    accessRole: "member",
    membershipStatus: "active"
  }, "PERMISSION_DENIED");
  await expectCallableFailure(branchAdminToken, {
    uid: "test-pending-branch-user",
    isApproved: true,
    branchId: "canada-daniel-test-church",
    accessRole: "branch_admin",
    membershipStatus: "active"
  }, "PERMISSION_DENIED");

  const regionAdminToken = await signIn("region-admin@example.test", "password123");
  await callSetUserAccess(regionAdminToken, {
    uid: "test-other-user",
    isApproved: true,
    branchId: "canada-other-test-church",
    accessRole: "branch_admin",
    membershipStatus: "active"
  });
  await expectCallableFailure(regionAdminToken, {
    uid: "test-outside-region-user",
    isApproved: true,
    branchId: "korea-seoul-test-church",
    accessRole: "member",
    membershipStatus: "active"
  }, "PERMISSION_DENIED");
  await expectCallableFailure(regionAdminToken, {
    uid: "test-other-user",
    isApproved: true,
    branchId: "canada-other-test-church",
    accessRole: "global_admin",
    membershipStatus: "active"
  }, "PERMISSION_DENIED");

  const pendingBranchUser = (await db.collection("users").doc("test-pending-branch-user").get()).data();
  if (pendingBranchUser?.isApproved !== true || pendingBranchUser?.membershipStatus !== "active") {
    throw new Error("Expected branch admin to approve same-branch pending member.");
  }

  console.log("Callable scoped admin access test passed.");
  console.log(JSON.stringify({
    uid: result.uid,
    accessRole: result.accessRole,
    branchId: result.branchId,
    membershipExists: membershipDoc.exists,
    scopedBranchApproval: pendingBranchUser?.membershipStatus
  }));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
