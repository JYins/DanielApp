#!/usr/bin/env node

const { createRequire } = require("node:module");
const path = require("node:path");

const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const projectId = process.env.GCLOUD_PROJECT || "demo-daniel-canada";

if (!authHost || !storageHost) {
  console.error("Refusing to run: Auth and Storage emulator hosts must be set.");
  process.exit(1);
}

const webRequire = createRequire(path.resolve(__dirname, "../admin-web/package.json"));
const { initializeApp } = webRequire("firebase/app");
const {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} = webRequire("firebase/auth");
const {
  connectStorageEmulator,
  getBytes,
  getStorage,
  ref,
  uploadBytes,
} = webRequire("firebase/storage");

const app = initializeApp({
  apiKey: "fake-api-key",
  appId: "storage-rules-test",
  authDomain: `${projectId}.firebaseapp.com`,
  projectId,
  storageBucket: `${projectId}.appspot.com`,
});
const auth = getAuth(app);
const storage = getStorage(app);
const [authHostname, authPort] = authHost.split(":");
const [storageHostname, storagePort] = storageHost.split(":");
connectAuthEmulator(auth, `http://${authHostname}:${authPort}`, { disableWarnings: true });
connectStorageEmulator(storage, storageHostname, Number(storagePort));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function expectDenied(action, label) {
  try {
    await action();
  } catch (error) {
    assert(error?.code === "storage/unauthorized", `${label} failed with ${error?.code || error}.`);
    return;
  }
  throw new Error(`${label} should have been denied.`);
}

async function main() {
  const pdf = new Uint8Array(Buffer.from("%PDF-1.4\nDaniel App emulator test\n%%EOF\n"));
  const allowedRef = ref(storage, "resources/storage-rules-test/allowed.pdf");

  await signInWithEmailAndPassword(auth, "approved@example.test", "password123");
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/member.pdf"), pdf, { contentType: "application/pdf" }),
    "Member PDF upload"
  );

  await signInWithEmailAndPassword(auth, "admin@example.test", "password123");
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/not-pdf.txt"), new Uint8Array([1, 2, 3]), { contentType: "text/plain" }),
    "Non-PDF upload"
  );
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/too-large.pdf"), new Uint8Array(50 * 1024 * 1024), { contentType: "application/pdf" }),
    "50 MiB PDF upload"
  );

  await uploadBytes(allowedRef, pdf, { contentType: "application/pdf" });
  await signOut(auth);
  const publicBytes = await getBytes(allowedRef);
  assert(publicBytes.byteLength === pdf.byteLength, "Public Resource PDF read returned unexpected bytes.");

  console.log("Storage rules tests passed: member denied, non-PDF denied, 50 MiB denied, admin PDF/public read allowed.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
