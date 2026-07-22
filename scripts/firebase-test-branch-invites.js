#!/usr/bin/env node

const { createRequire } = require("node:module");
const path = require("node:path");
const functionsRequire = createRequire(path.resolve(__dirname, "../functions/package.json"));
const { initializeApp } = functionsRequire("firebase-admin/app");
const { getAuth } = functionsRequire("firebase-admin/auth");
const { FieldValue, getFirestore } = functionsRequire("firebase-admin/firestore");

const projectId = process.env.GCLOUD_PROJECT || "demo-daniel-canada";
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;

if (!authHost || !firestoreHost) {
  console.error("Refusing to run: Auth and Firestore emulator hosts must be set.");
  process.exit(1);
}

initializeApp({ projectId });
const auth = getAuth();
const db = getFirestore();

async function signIn(email, password = "password123") {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true })
    }
  );
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`Auth sign-in failed: ${JSON.stringify(body)}`);
  }
  return body.idToken;
}

async function callFunction(name, idToken, data) {
  const response = await fetch(
    `http://${functionHost}/${projectId}/us-central1/${name}`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${idToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ data })
    }
  );
  const body = await response.json();
  if (!response.ok || body.error) {
    const error = new Error(`Callable ${name} failed: ${JSON.stringify(body)}`);
    error.callableStatus = body?.error?.status;
    error.callableDetails = body?.error?.details;
    throw error;
  }
  return body.result;
}

async function expectCallableFailure(name, idToken, data, expectedStatus, expectedReason) {
  try {
    await callFunction(name, idToken, data);
  } catch (error) {
    if (error.callableStatus !== expectedStatus) {
      throw new Error(`Expected ${name} ${expectedStatus}, got ${error.message}`);
    }
    if (expectedReason && error.callableDetails?.reason !== expectedReason) {
      throw new Error(`Expected ${name} reason ${expectedReason}, got ${error.message}`);
    }
    return;
  }
  throw new Error(`Expected ${name} to fail with ${expectedStatus}.`);
}

async function createUnassignedUser(suffix, emailVerified = true) {
  const uid = `test-invite-${suffix}`;
  const email = `${uid}@example.test`;
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw error;
    }
  }
  await auth.createUser({
    uid,
    email,
    password: "password123",
    emailVerified
  });
  await auth.setCustomUserClaims(uid, {
    role: "member",
    accessRole: "member",
    membershipStatus: "unassigned",
    isApproved: false,
    branchId: ""
  });
  await db.collection("users").doc(uid).set({
    userId: uid,
    email,
    name: `Invite Test ${suffix}`,
    isApproved: false,
    role: "member",
    accessRole: "member",
    membershipStatus: "unassigned",
    orgId: "daniel-branch-church",
    regionId: "",
    branchId: "",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });
  return { uid, email, idToken: await signIn(email) };
}

async function firestoreGet(idToken, collection, documentId) {
  return fetch(
    `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${collection}/${documentId}`,
    { headers: { Authorization: `Bearer ${idToken}` } }
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function decodeJwtPayload(idToken) {
  const payload = idToken.split(".")[1];
  return JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
}

async function main() {
  const branchAdminToken = await signIn("branch-admin@example.test");
  const globalAdminToken = await signIn("admin@example.test");
  const otherMemberToken = await signIn("other@example.test");

  await expectCallableFailure(
    "createBranchInvite",
    branchAdminToken,
    { branchId: "canada-other-test-church", label: "Cross branch" },
    "PERMISSION_DENIED"
  );

  const initialInvite = await callFunction("createBranchInvite", branchAdminToken, {
    branchId: "canada-daniel-test-church",
    label: "Canada pilot"
  });
  assert(/^[0-9A-HJKMNP-TV-Z]{4}(-[0-9A-HJKMNP-TV-Z]{4}){3}$/.test(initialInvite.code),
    `Unexpected invite format: ${initialInvite.code}`);

  const storedInitial = (await db.collection("branchInvites").doc(initialInvite.inviteId).get()).data();
  assert(storedInitial.tokenHash && storedInitial.tokenHash.length === 64, "Expected SHA-256 token hash.");
  assert(!JSON.stringify(storedInitial).includes(initialInvite.code), "Plaintext invite code was persisted.");
  assert(!JSON.stringify(storedInitial).includes(initialInvite.code.replace(/-/g, "")),
    "Normalized plaintext invite code was persisted.");
  assert(storedInitial.maxUses === 250, "Expected default maxUses 250.");

  const listed = await callFunction("listBranchInvites", branchAdminToken, {
    branchId: "canada-daniel-test-church"
  });
  assert(listed.invites.some((invite) => invite.inviteId === initialInvite.inviteId),
    "Created invite was missing from scoped list.");
  assert(!JSON.stringify(listed).includes("tokenHash") && !JSON.stringify(listed).includes(initialInvite.code),
    "Invite list exposed a secret.");

  const firstUserToken = await signIn("unassigned@example.test");
  const redeemed = await callFunction("redeemBranchInvite", firstUserToken, {
    code: initialInvite.code.toLowerCase()
  });
  assert(redeemed.membershipStatus === "pending", "Invite redemption must create pending access.");

  const firstUser = (await db.collection("users").doc("test-unassigned-user").get()).data();
  const firstMembership = (await db.collection("branchMemberships")
    .doc("canada-daniel-test-church_test-unassigned-user").get()).data();
  const firstAudit = await db.collection("inviteRedemptions")
    .doc(`${initialInvite.inviteId}_test-unassigned-user`).get();
  assert(firstUser.accessRole === "member" && firstUser.membershipStatus === "pending" && !firstUser.isApproved,
    "Redeemed user was not constrained to pending member.");
  assert(firstMembership.accessRole === "member" && firstMembership.status === "pending",
    "Pending branch membership was not created.");
  assert(firstAudit.exists, "Successful redemption audit was not created.");

  const idempotent = await callFunction("redeemBranchInvite", firstUserToken, { code: initialInvite.code });
  const afterIdempotency = (await db.collection("branchInvites").doc(initialInvite.inviteId).get()).data();
  assert(idempotent.idempotent === true && afterIdempotency.useCount === 1,
    "Repeated redemption was not idempotent.");

  await callFunction("setUserAccessAdmin", branchAdminToken, {
    uid: "test-unassigned-user",
    isApproved: true,
    branchId: "canada-daniel-test-church",
    accessRole: "member",
    membershipStatus: "active"
  });
  const approvedIdempotent = await callFunction("redeemBranchInvite", firstUserToken, {
    code: initialInvite.code
  });
  const refreshedApprovedToken = await signIn("unassigned@example.test");
  const approvedClaims = decodeJwtPayload(refreshedApprovedToken);
  assert(approvedIdempotent.membershipStatus === "active" && approvedClaims.membershipStatus === "active",
    "Idempotent redemption downgraded an already approved member.");

  await expectCallableFailure(
    "redeemBranchInvite",
    globalAdminToken,
    { code: initialInvite.code },
    "PERMISSION_DENIED"
  );

  const rotatedInvite = await callFunction("createBranchInvite", branchAdminToken, {
    branchId: "canada-daniel-test-church",
    label: "Rotated"
  });
  const oldInvite = (await db.collection("branchInvites").doc(initialInvite.inviteId).get()).data();
  assert(oldInvite.status === "revoked" && oldInvite.revokeReason === "rotated",
    "Creating a replacement did not revoke the prior active invite.");

  const revokedUser = await createUnassignedUser("revoked");
  await expectCallableFailure(
    "redeemBranchInvite",
    revokedUser.idToken,
    { code: initialInvite.code },
    "FAILED_PRECONDITION",
    "revoked"
  );

  await callFunction("revokeBranchInvite", branchAdminToken, { inviteId: rotatedInvite.inviteId });
  await callFunction("revokeBranchInvite", branchAdminToken, { inviteId: rotatedInvite.inviteId });
  const manuallyRevoked = (await db.collection("branchInvites").doc(rotatedInvite.inviteId).get()).data();
  assert(manuallyRevoked.status === "revoked", "Manual revocation was not idempotent.");

  const expiredInvite = await callFunction("createBranchInvite", branchAdminToken, {
    branchId: "canada-daniel-test-church",
    label: "Expired"
  });
  await db.collection("branchInvites").doc(expiredInvite.inviteId).update({
    expiresAt: new Date(Date.now() - 1000)
  });
  const expiredUser = await createUnassignedUser("expired");
  await expectCallableFailure(
    "redeemBranchInvite",
    expiredUser.idToken,
    { code: expiredInvite.code },
    "FAILED_PRECONDITION",
    "expired"
  );

  const exhaustedInvite = await callFunction("createBranchInvite", branchAdminToken, {
    branchId: "canada-daniel-test-church",
    label: "Exhausted"
  });
  await db.collection("branchInvites").doc(exhaustedInvite.inviteId).update({ maxUses: 1, useCount: 1 });
  const exhaustedUser = await createUnassignedUser("exhausted");
  await expectCallableFailure(
    "redeemBranchInvite",
    exhaustedUser.idToken,
    { code: exhaustedInvite.code },
    "RESOURCE_EXHAUSTED",
    "usage-limit"
  );

  const concurrentInvite = await callFunction("createBranchInvite", branchAdminToken, {
    branchId: "canada-daniel-test-church",
    label: "Concurrent final use"
  });
  await db.collection("branchInvites").doc(concurrentInvite.inviteId).update({ maxUses: 1, useCount: 0 });
  const concurrentA = await createUnassignedUser("concurrent-a");
  const concurrentB = await createUnassignedUser("concurrent-b");
  const concurrentResults = await Promise.allSettled([
    callFunction("redeemBranchInvite", concurrentA.idToken, { code: concurrentInvite.code }),
    callFunction("redeemBranchInvite", concurrentB.idToken, { code: concurrentInvite.code })
  ]);
  assert(concurrentResults.filter((result) => result.status === "fulfilled").length === 1,
    "Exactly one concurrent redemption should receive the final use.");
  const concurrentStored = (await db.collection("branchInvites").doc(concurrentInvite.inviteId).get()).data();
  assert(concurrentStored.useCount === 1, "Concurrent redemption exceeded maxUses.");

  const unverifiedInvite = await callFunction("createBranchInvite", branchAdminToken, {
    branchId: "canada-daniel-test-church",
    label: "Email verification"
  });
  const unverifiedUser = await createUnassignedUser("unverified", false);
  await expectCallableFailure(
    "redeemBranchInvite",
    unverifiedUser.idToken,
    { code: unverifiedInvite.code },
    "FAILED_PRECONDITION",
    "email-not-verified"
  );

  const otherBranchInvite = await callFunction("createBranchInvite", globalAdminToken, {
    branchId: "canada-other-test-church",
    label: "Other branch"
  });
  await expectCallableFailure(
    "revokeBranchInvite",
    branchAdminToken,
    { inviteId: otherBranchInvite.inviteId },
    "PERMISSION_DENIED"
  );

  const deniedInviteRead = await firestoreGet(globalAdminToken, "branchInvites", otherBranchInvite.inviteId);
  assert(deniedInviteRead.status === 403, "Client SDK access to invite documents must always be denied.");
  const sameConnect = await firestoreGet(branchAdminToken, "branchConnect", "canada-daniel-test-church");
  const otherConnect = await firestoreGet(branchAdminToken, "branchConnect", "canada-other-test-church");
  const otherMemberConnect = await firestoreGet(otherMemberToken, "branchConnect", "canada-other-test-church");
  assert(sameConnect.ok, "Active member could not read their branch Connect configuration.");
  assert(otherConnect.status === 403, "Active member could read another branch Connect configuration.");
  assert(otherMemberConnect.ok, "Other branch member could not read their own Connect configuration.");
  const connectSeed = (await db.collection("branchConnect").doc("canada-daniel-test-church").get()).data();
  assert(connectSeed.groupNameZh && connectSeed.groupNameEn && connectSeed.groupNameKo && connectSeed.kakaoURL,
    "branchConnect seed does not match the shared iOS/admin field contract.");
  assert(!connectSeed.kakaoGroupName && !connectSeed.kakaoTalkURL,
    "branchConnect seed still contains obsolete field names.");

  const ownNewsletter = await firestoreGet(branchAdminToken, "newsletters", "test-weekly-newsletter");
  const otherNewsletter = await firestoreGet(branchAdminToken, "newsletters", "test-other-branch-newsletter");
  assert(ownNewsletter.ok, "Active member could not read their branch newsletter.");
  assert(otherNewsletter.status === 403, "Active member could read another branch newsletter.");

  console.log("Branch invite callable and branch isolation tests passed.");
  console.log(JSON.stringify({
    inviteFormat: initialInvite.code.replace(/[0-9A-HJKMNP-TV-Z]/g, "X"),
    persistedPlaintext: false,
    membershipStatus: firstUser.membershipStatus,
    idempotentUseCount: afterIdempotency.useCount,
    concurrentFinalUse: concurrentStored.useCount,
    crossBranchRulesDenied: true
  }));
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
