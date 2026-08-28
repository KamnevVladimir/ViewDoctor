#!/usr/bin/env node
import { spawn } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "viewdoctor", version: "0.1.7" });

export function runViewDoctor(args, options = {}) {
  const executable = options.executable ?? process.env.VIEWDOCTOR_BIN ?? "viewdoctor";
  const timeoutMs = options.timeoutMs ?? 120_000;
  return new Promise((resolveRun, reject) => {
    const child = spawn(executable, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => child.kill("SIGTERM"), timeoutMs);
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", reject);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      resolveRun({ code: code ?? 1, signal, stdout, stderr });
    });
  });
}

function toolResult(result) {
  const text = [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join("\n");
  return { content: [{ type: "text", text: text || `ViewDoctor exited with status ${result.code}.` }], isError: result.code > 1 };
}

export function buildScanArguments({ root, scanMode, gitDiff, base, format, failOn }) {
  const args = ["scan", resolve(root), "--format", format ?? "agent"];
  const effectiveMode = scanMode ?? (gitDiff === false ? "all" : "changed");
  if (base) args.push("--base", base);
  else if (effectiveMode === "changed") args.push("--git-diff");
  else if (effectiveMode === "staged") args.push("--staged");
  if (failOn) args.push("--fail-on", failOn);
  return args;
}

server.registerTool("viewdoctor_scan", {
  title: "Scan Swift changes with ViewDoctor",
  description: "Run local deterministic SwiftUI analysis. Changed mode includes new untracked Swift files; staged mode is intended for pre-commit checks.",
  inputSchema: {
    root: z.string().min(1).describe("Path to the local Swift repository"),
    scanMode: z.enum(["changed", "staged", "all"]).optional().describe("Scope to scan; defaults to changed"),
    gitDiff: z.boolean().optional().describe("Compatibility alias: false selects all files"),
    base: z.string().min(1).optional().describe("Optional Git base revision"),
    format: z.enum(["text", "json", "agent", "sarif"]).default("agent"),
    failOn: z.enum(["note", "warning", "error"]).optional().describe("Optional exit-code threshold")
  },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }
}, async (input) => toolResult(await runViewDoctor(buildScanArguments(input))));

server.registerTool("viewdoctor_graph", {
  title: "Inspect a Swift module graph",
  description: "Map local SwiftPM, Tuist, Xcode, and folder-derived module relationships.",
  inputSchema: { root: z.string().min(1).describe("Path to the local Swift repository") },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }
}, async ({ root }) => toolResult(await runViewDoctor(["graph", resolve(root)])));

function isMainModule() {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(resolve(process.argv[1]));
  } catch {
    return false;
  }
}

if (isMainModule()) {
  await server.connect(new StdioServerTransport());
}
