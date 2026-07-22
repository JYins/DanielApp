function loadFirebaseCliAuth() {
  const candidates = [
    "firebase-tools/lib/auth",
    "/opt/homebrew/lib/node_modules/firebase-tools/lib/auth",
    "/usr/local/lib/node_modules/firebase-tools/lib/auth"
  ];

  for (const candidate of candidates) {
    try {
      return require(candidate);
    } catch {
      // Try the next known install location.
    }
  }

  throw new Error("Unable to load firebase-tools auth module. Install Firebase CLI with npm or Homebrew.");
}

module.exports = loadFirebaseCliAuth();
