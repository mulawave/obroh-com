import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const policyPath = path.join(__dirname, "deploy-boundary-policy.json");
const policy = JSON.parse(fs.readFileSync(policyPath, "utf8"));
const validateEnv = process.argv.includes("--env");

let failed = false;

function fail(message) {
  failed = true;
  console.error(`DEPLOY BOUNDARY ERROR: ${message}`);
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(repoRoot, relativePath), "utf8"));
}

function readText(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), "utf8");
}

function normalize(value) {
  return String(value).toLowerCase();
}

function validateFirebaseConfigs() {
  const firebaseConfigs = fs
    .readdirSync(repoRoot)
    .filter((fileName) => /^firebase.*\.json$/i.test(fileName));

  for (const fileName of firebaseConfigs) {
    if (!policy.allowedFirebaseConfigs.includes(fileName)) {
      fail(
        `Unexpected Firebase config '${fileName}' exists in this repo. Cross-app hosting configs must not live in the Obroh repo.`
      );
    }
  }

  const firebaseConfig = readJson("firebase.json");
  const hostingEntries = Array.isArray(firebaseConfig.hosting)
    ? firebaseConfig.hosting
    : [firebaseConfig.hosting].filter(Boolean);

  if (hostingEntries.length === 0) {
    fail("firebase.json must declare at least one hosting entry.");
    return;
  }

  for (const hostingEntry of hostingEntries) {
    if (!policy.allowedHostingSites.includes(hostingEntry.site)) {
      fail(
        `firebase.json targets hosting site '${hostingEntry.site}'. Allowed sites for this repo: ${policy.allowedHostingSites.join(", ")}.`
      );
    }

    if (!policy.allowedHostingPublicDirs.includes(hostingEntry.public)) {
      fail(
        `firebase.json uses public dir '${hostingEntry.public}'. Allowed public dirs for this repo: ${policy.allowedHostingPublicDirs.join(", ")}.`
      );
    }

    const predeploy = Array.isArray(hostingEntry.predeploy)
      ? hostingEntry.predeploy
      : hostingEntry.predeploy
        ? [hostingEntry.predeploy]
        : [];

    if (!predeploy.includes(policy.requiredPredeployCommand)) {
      fail(
        `firebase.json hosting entry for '${hostingEntry.site}' must include predeploy command '${policy.requiredPredeployCommand}'.`
      );
    }
  }
}

function validateRepoFiles() {
  for (const relativePath of policy.repoScanFiles) {
    const filePath = path.join(repoRoot, relativePath);
    if (!fs.existsSync(filePath)) {
      continue;
    }

    const content = normalize(readText(relativePath));
    for (const namespace of policy.forbiddenNamespaces) {
      if (content.includes(normalize(namespace))) {
        fail(`Forbidden namespace '${namespace}' found in ${relativePath}.`);
      }
    }
  }
}

function validateEnvRules() {
  for (const [envKey, rules] of Object.entries(policy.envRules)) {
    const rawValue = process.env[envKey];
    if (!rawValue) {
      fail(`Required deploy env '${envKey}' is missing.`);
      continue;
    }

    const value = normalize(rawValue);

    if (rules.allowedExact && !rules.allowedExact.map(normalize).includes(value)) {
      fail(
        `Env '${envKey}' has value '${rawValue}', but only these values are allowed: ${rules.allowedExact.join(", ")}.`
      );
    }

    if (
      rules.mustContainAny &&
      !rules.mustContainAny.some((token) => value.includes(normalize(token)))
    ) {
      fail(
        `Env '${envKey}' has value '${rawValue}', but it must contain one of: ${rules.mustContainAny.join(", ")}.`
      );
    }

    if (
      rules.mustNotContain &&
      rules.mustNotContain.some((token) => value.includes(normalize(token)))
    ) {
      fail(
        `Env '${envKey}' has value '${rawValue}', which includes a forbidden namespace: ${rules.mustNotContain.join(", ")}.`
      );
    }
  }
}

function validateProjectSelection() {
  const firebaserc = readJson(".firebaserc");
  const defaultProject = firebaserc?.projects?.default;
  if (!policy.sharedFirebaseProjects.includes(defaultProject)) {
    fail(
      `.firebaserc default project is '${defaultProject}'. Allowed shared Firebase projects: ${policy.sharedFirebaseProjects.join(", ")}.`
    );
  }
}

validateFirebaseConfigs();
validateRepoFiles();
validateProjectSelection();

if (validateEnv) {
  validateEnvRules();
}

if (failed) {
  process.exit(1);
}

console.log(
  validateEnv
    ? "Deploy boundary validation passed for repo files and workflow env values."
    : "Deploy boundary validation passed for repo files."
);