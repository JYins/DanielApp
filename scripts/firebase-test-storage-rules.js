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
  const audio = new Uint8Array(Buffer.from("ID3Daniel App hymn audio emulator test"));
  const allowedRef = ref(storage, "resources/storage-rules-test/allowed.pdf");
  const allowedAudioRef = ref(storage, "resources/storage-rules-test/audio/allowed.mp3");
  const newsletterImage = new Uint8Array([137, 80, 78, 71]);
  const branchNewsletterRef = ref(storage, "newsletters/canada-daniel-test-church/announcement.png");

  await signInWithEmailAndPassword(auth, "approved@example.test", "password123");
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/member.pdf"), pdf, { contentType: "application/pdf" }),
    "Member PDF upload"
  );
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/audio/member.mp3"), audio, { contentType: "audio/mpeg" }),
    "Member audio upload"
  );

  await signInWithEmailAndPassword(auth, "branch-admin@example.test", "password123");
  await uploadBytes(branchNewsletterRef, newsletterImage, { contentType: "image/png" });
  await expectDenied(
    () => uploadBytes(ref(storage, "newsletters/canada-other-test-church/cross-branch.png"), newsletterImage, { contentType: "image/png" }),
    "Branch admin cross-branch newsletter upload"
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
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/audio/not-audio.pdf"), pdf, { contentType: "application/pdf" }),
    "Non-audio upload in hymn audio path"
  );
  await expectDenied(
    () => uploadBytes(ref(storage, "resources/storage-rules-test/audio/too-large.mp3"), new Uint8Array(100 * 1024 * 1024), { contentType: "audio/mpeg" }),
    "100 MiB audio upload"
  );

  await uploadBytes(allowedRef, pdf, { contentType: "application/pdf" });
  await uploadBytes(allowedAudioRef, audio, { contentType: "audio/mpeg" });
  await signInWithEmailAndPassword(auth, "approved@example.test", "password123");
  const ownBranchImage = await getBytes(branchNewsletterRef);
  assert(ownBranchImage.byteLength === newsletterImage.byteLength, "Active member could not read own-branch newsletter image.");

  await signInWithEmailAndPassword(auth, "other@example.test", "password123");
  await expectDenied(() => getBytes(branchNewsletterRef), "Cross-branch newsletter image read");

  await signOut(auth);
  const publicBytes = await getBytes(allowedRef);
  const publicAudioBytes = await getBytes(allowedAudioRef);
  assert(publicBytes.byteLength === pdf.byteLength, "Public Resource PDF read returned unexpected bytes.");
  assert(publicAudioBytes.byteLength === audio.byteLength, "Public hymn audio read returned unexpected bytes.");

  console.log("Storage rules tests passed: Resource PDF/audio limits enforced; branch newsletter upload/read isolation enforced.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
