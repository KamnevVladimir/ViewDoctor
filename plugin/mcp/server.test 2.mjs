import assert from "node:assert/strict";
import test from "node:test";
import { runViewDoctor } from "./server.mjs";

test("passes arguments without shell interpretation", async () => {
  const result = await runViewDoctor(["scan", "/tmp/a path;echo unsafe", "--format", "json"], { executable: "/bin/echo" });
  assert.equal(result.code, 0);
  assert.match(result.stdout, /a path;echo unsafe/);
});
