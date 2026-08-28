import assert from "node:assert/strict";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { buildScanArguments, runViewDoctor } from "./server.mjs";

test("passes arguments without shell interpretation", async () => {
  const result = await runViewDoctor(["scan", "/tmp/a path;echo unsafe", "--format", "json"], { executable: "/bin/echo" });
  assert.equal(result.code, 0);
  assert.match(result.stdout, /a path;echo unsafe/);
});

test("builds explicit changed and staged scan scopes", () => {
  assert.deepEqual(
    buildScanArguments({ root: "/tmp/project", format: "agent" }),
    ["scan", "/tmp/project", "--format", "agent", "--git-diff"]
  );
  assert.deepEqual(
    buildScanArguments({ root: "/tmp/project", scanMode: "staged", failOn: "warning" }),
    ["scan", "/tmp/project", "--format", "agent", "--staged", "--fail-on", "warning"]
  );
});

test("starts when invoked through a symlinked entry point", async (context) => {
  const directory = await mkdtemp(join(tmpdir(), "viewdoctor-mcp-"));
  context.after(() => rm(directory, { recursive: true, force: true }));
  const entryPoint = join(directory, "server.mjs");
  await symlink(fileURLToPath(new URL("./server.mjs", import.meta.url)), entryPoint);

  const client = new Client({ name: "viewdoctor-test", version: "1.0.0" });
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [entryPoint],
    stderr: "inherit"
  });
  await client.connect(transport);
  context.after(() => client.close());

  const tools = await client.listTools();
  assert.deepEqual(
    tools.tools.map((tool) => tool.name).sort(),
    ["viewdoctor_graph", "viewdoctor_scan"]
  );
});
