#!/usr/bin/env node

// Parallel Task Validator: Check for file path conflicts among [P] tasks
// within the same phase.
//
// Usage: afc-parallel-validate.mjs <tasks_file_path>
// Exit 0: valid (no overlaps, or no [P] tasks)
// Exit 1: overlaps detected — prints conflict details

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

const phasePattern = /^## Phase (\d+)/;
const taskPPattern = /^\s*-\s*\[[ xX]\]\s+(T\d+)\s+\[P\]/;
const backtickPattern = /`([^`]+)`/g;

let currentPhase = '';
let totalPTasks = 0;
const conflicts = [];
const phasesWithP = new Set();

// Single-pass parsing
let phaseFileMap = new Map(); // file_path -> task_id

for (const line of content.split(/\r?\n/)) {
  const phaseMatch = line.match(phasePattern);
  if (phaseMatch) {
    currentPhase = phaseMatch[1];
    phaseFileMap = new Map();
    continue;
  }

  if (!currentPhase) continue;

  const taskMatch = line.match(taskPPattern);
  if (!taskMatch) continue;

  const taskId = taskMatch[1];
  totalPTasks++;
  phasesWithP.add(currentPhase);

  // Extract backtick-wrapped file paths (containing / or .)
  let match;
  backtickPattern.lastIndex = 0;
  while ((match = backtickPattern.exec(line)) !== null) {
    const path = match[1];
    if (!/[/.]/.test(path)) continue;

    const existing = phaseFileMap.get(path);
    if (existing) {
      conflicts.push(`CONFLICT: Phase ${currentPhase} — ${existing} and ${taskId} both target ${path}`);
    } else {
      phaseFileMap.set(path, taskId);
    }
  }
}

if (totalPTasks === 0) {
  process.stdout.write('Valid: no [P] tasks found, nothing to validate\n');
  process.exit(0);
}

if (conflicts.length > 0) {
  process.stdout.write(conflicts.join('\n') + '\n');
  process.exit(1);
}

process.stdout.write(`Valid: ${totalPTasks} [P] tasks across ${phasesWithP.size} phases, no file overlaps\n`);
