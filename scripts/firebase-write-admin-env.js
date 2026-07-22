#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const [configPath, outputPath = "admin-web/.env.local"] = process.argv.slice(2);

if (!configPath) {
  console.error("Usage: node scripts/firebase-write-admin-env.js <firebase-web-config.json> [output]");
  process.exit(1);
}

const resolvedConfig = path.resolve(configPath);
const resolvedOutput = path.resolve(outputPath);
const config = JSON.parse(fs.readFileSync(resolvedConfig, "utf8"));

if (config.private_key || config.privateKey || config.client_email) {
  console.error("Refusing to process a service-account or private-key file.");
  process.exit(1);
}

const fields = [
  ["VITE_FIREBASE_API_KEY", config.apiKey],
  ["VITE_FIREBASE_AUTH_DOMAIN", config.authDomain],
  ["VITE_FIREBASE_PROJECT_ID", config.projectId],
  ["VITE_FIREBASE_STORAGE_BUCKET", config.storageBucket],
  ["VITE_FIREBASE_MESSAGING_SENDER_ID", config.messagingSenderId],
  ["VITE_FIREBASE_APP_ID", config.appId],
];

const missing = fields.filter(([, value]) => typeof value !== "string" || !value.trim());
if (missing.length > 0) {
  console.error(`Firebase Web config is missing: ${missing.map(([key]) => key).join(", ")}`);
  process.exit(1);
}

const contents = `${fields.map(([key, value]) => `${key}=${value}`).join("\n")}\n`;
fs.writeFileSync(resolvedOutput, contents, { encoding: "utf8", mode: 0o600 });
console.log(`Wrote ${fields.length} Firebase Web values to ${resolvedOutput}.`);
