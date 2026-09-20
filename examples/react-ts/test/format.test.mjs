import assert from "node:assert/strict";
import test from "node:test";

// O teste consome a saída compilada, mantendo o fixture livre de runner de TS.
const { formatarMoeda } = await import("../dist/format.js");

test("formata em BRL", () => {
  assert.match(formatarMoeda(10), /10,00/);
});
