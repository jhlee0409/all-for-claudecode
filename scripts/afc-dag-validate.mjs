#!/usr/bin/env node

// DAG Validator: Check task dependency graph for circular references
// Parses tasks.md and validates that depends: declarations form a valid DAG.
//
// Usage: afc-dag-validate.mjs <tasks_file_path>
// Exit 0: valid DAG (no cycles)
// Exit 1: cycle detected — prints cycle path

import { readFileSync } from 'fs';

const tasksFile = process.argv[2];
if (!tasksFile) {
  process.stderr.write(`Usage: ${process.argv[1]} <tasks_file_path>\n`);
  process.exit(1);
}

let content;
try {
  content = readFileSync(tasksFile, 'utf8');
} catch {
  process.stderr.write(`Error: file not found: ${tasksFile}\n`);
  process.exit(1);
}

// Parse tasks and dependencies
const taskPattern = /^\s*-\s*\[[ xX]\]\s+(T\d+)/;
const depsPattern = /depends:\s*\[([^\]]*)\]/;

const nodes = new Set();
const edges = new Map(); // from -> [to, ...]

for (const line of content.split(/\r?\n/)) {
  const taskMatch = line.match(taskPattern);
  if (!taskMatch) continue;

  const taskId = taskMatch[1];
  nodes.add(taskId);
  if (!edges.has(taskId)) edges.set(taskId, []);

  const depsMatch = line.match(depsPattern);
  if (depsMatch) {
    const deps = depsMatch[1].match(/T\d+/g) || [];
    for (const dep of deps) {
      // Edge: dep → taskId (taskId depends on dep)
      if (!edges.has(dep)) edges.set(dep, []);
      edges.get(dep).push(taskId);
    }
  }
}

if (nodes.size === 0) {
  process.stdout.write('Valid: no tasks found, nothing to validate\n');
  process.exit(0);
}

// DFS cycle detection with full cycle path
const WHITE = 0, GRAY = 1, BLACK = 2;
const color = new Map();
const parent = new Map();

for (const node of nodes) color.set(node, WHITE);

function dfs(node) {
  color.set(node, GRAY);
  for (const neighbor of (edges.get(node) || [])) {
    if (!color.has(neighbor)) continue;
    if (color.get(neighbor) === GRAY) {
      // Cycle found — reconstruct path
      const cycle = [neighbor, node];
      let cur = node;
      while (cur !== neighbor && parent.has(cur)) {
        cur = parent.get(cur);
        cycle.push(cur);
      }
      cycle.reverse();
      process.stdout.write(`CYCLE: ${cycle.join(' → ')}\n`);
      process.exit(1);
    }
    if (color.get(neighbor) === WHITE) {
      parent.set(neighbor, node);
      dfs(neighbor);
    }
  }
  color.set(node, BLACK);
}

for (const node of nodes) {
  if (color.get(node) === WHITE) {
    dfs(node);
  }
}

process.stdout.write(`Valid: ${nodes.size} tasks, no circular dependencies\n`);
