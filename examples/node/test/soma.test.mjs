import assert from "node:assert/strict";
import test from "node:test";
import { soma } from "../src/index.mjs";

test("soma dois inteiros", () => {
  assert.equal(soma(2, 3), 5);
});
