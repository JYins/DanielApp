#!/usr/bin/env node

const assert = require("assert");
const path = require("path");
const {
  EXPECTED_BRANCH_IDS,
  assertProductionReady,
  buildPlan,
  createOnlyWrites,
  missingOperationalFields,
  readManifest,
  validateManifest
} = require("./firebase-init-canada-pilot");

const manifestPath = path.resolve("config/canada-pilot.manifest.json");
const manifest = validateManifest(readManifest(manifestPath));
const plan = buildPlan(manifest, "2026-07-22T00:00:00.000Z");
const missing = missingOperationalFields(manifest);

assert.deepStrictEqual(manifest.branches.map(branch => branch.id), EXPECTED_BRANCH_IDS);
assert.strictEqual(plan.branches.length, 4);
assert.strictEqual(plan.branchConnect.length, 4);
assert.strictEqual(missing.length, 16, "Every unknown operational field must remain explicit.");
assert(missing.includes("canada-toronto-church.branchAdminEmail"));
assert(missing.includes("canada-montreal-church.kakaoURL"));
assert.throws(
  () => assertProductionReady({ ...manifest, template: false }, "config/canada-pilot.local.json"),
  /branchAdminEmail/
);

const readyManifest = structuredClone(manifest);
readyManifest.template = false;
for (const branch of readyManifest.branches) {
  branch.city = "Verified city";
  branch.timezone = "America/Toronto";
  branch.branchAdminEmail = `${branch.id}@example.com`;
  branch.kakaoURL = `https://open.kakao.com/o/${branch.code.toLowerCase()}`;
}
const readyPlan = buildPlan(validateManifest(readyManifest), "2026-07-22T00:00:00.000Z");
const writes = createOnlyWrites("demo-daniel-canada", readyPlan);
assert.strictEqual(writes.length, 9, "Only one region, four branches, and four branchConnect docs are allowed.");
assert(writes.every(write => write.currentDocument?.exists === false), "All writes must be create-only.");
assert(writes.every(write => !write.update.name.includes("/users/")), "Pilot initialization must never write users.");
assert(writes.every(write => !write.update.name.includes("/branchMemberships/")), "Pilot initialization must never write memberships.");
assert(writes.every(write => !write.update.name.includes("/branchInvites/")), "Pilot initialization must never generate invite tokens.");

const invalid = structuredClone(manifest);
invalid.branches.push({ ...invalid.branches[0], id: "unexpected-branch" });
assert.throws(() => validateManifest(invalid), /branches must contain exactly/);

console.log("Canada pilot manifest safety tests passed.");
console.log({ branchCount: plan.branches.length, createOnlyWrites: writes.length, explicitPlaceholders: missing.length });
