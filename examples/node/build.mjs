// Build trivial: o fixture precisa de um script 'build' que produza ./dist,
// para exercitar o upload de artifact do workflow.
import { cp, mkdir, rm } from "node:fs/promises";

await rm("dist", { force: true, recursive: true });
await mkdir("dist", { recursive: true });
await cp("src", "dist", { recursive: true });
console.log("build: src -> dist");
