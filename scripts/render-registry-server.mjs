#!/usr/bin/env node

import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [version, bundleArgument, outputArgument] = process.argv.slice(2);
if (!/^\d+\.\d+\.\d+$/.test(version ?? "") || !bundleArgument || !outputArgument) {
  console.error("usage: scripts/render-registry-server.mjs <version> <bundle> <output>");
  process.exit(2);
}

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bundle = resolve(bundleArgument);
const output = resolve(outputArgument);
const repository = process.env.GITHUB_REPOSITORY ?? "KamnevVladimir/ViewDoctor";
const template = JSON.parse(readFileSync(resolve(root, "registry/server.template.json"), "utf8"));
const hash = createHash("sha256").update(readFileSync(bundle)).digest("hex");
const tag = `v${version}`;

template.version = version;
template.packages[0].identifier = `https://github.com/${repository}/releases/download/${tag}/ViewDoctor-${tag}.mcpb`;
template.packages[0].fileSha256 = hash;

mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(template, null, 2)}\n`);
console.log(output);
