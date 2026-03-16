import { spawn } from "child_process";
import { appendLog, updateTaskResult, updateTaskStatus } from "./db.js";

/** Track running processes so we can kill them if needed */
const running = new Map();

/** Default tool allowlist for Claude */
const ALLOWED_TOOLS = [
  "Read", "Edit", "Write", "Glob", "Grep",
  "Bash(npm *)", "Bash(npx *)", "Bash(git *)", "Bash(node *)",
  "Bash(ls *)", "Bash(mkdir *)", "Bash(cp *)", "Bash(mv *)",
  "Bash(cat *)", "Bash(pm2 *)",
  "Agent",
].join(",");

/**
 * Start a Claude -p process for a task.
 * Streams output to DB logs and SSE listeners.
 */
export function startTask(task, { onLog, onDone } = {}) {
  if (running.has(task.id)) {
    throw new Error(`Task ${task.id} is already running`);
  }

  updateTaskStatus(task.id, "running");

  const prompt = buildPrompt(task);

  const args = [
    "-p", prompt,
    "--output-format", "text",
    "--allowedTools", ALLOWED_TOOLS,
    "--max-turns", "200",
  ];

  const proc = spawn("claude", args, {
    cwd: task.project,
    env: { ...process.env, CLAUDE_CODE_DISABLE_CRON: "1" },
    stdio: ["pipe", "pipe", "pipe"],
  });

  running.set(task.id, proc);

  const log = (type, content) => {
    appendLog(task.id, type, content);
    onLog?.(task.id, type, content);
  };

  log("system", `Started claude process (PID: ${proc.pid})`);

  let output = "";

  proc.stdout.on("data", (data) => {
    const text = data.toString();
    output += text;
    log("stdout", text);
  });

  proc.stderr.on("data", (data) => {
    log("stderr", data.toString());
  });

  proc.on("close", (code) => {
    running.delete(task.id);

    const prUrl = extractPrUrl(output);
    const branch = extractBranch(output);

    if (code === 0) {
      updateTaskResult(task.id, {
        status: "passed",
        result: output.slice(-2000),
        prUrl,
        branch,
      });
      log("system", `Completed successfully${prUrl ? ` — PR: ${prUrl}` : ""}`);
    } else {
      updateTaskResult(task.id, {
        status: "failed",
        result: `Exit code: ${code}\n${output.slice(-2000)}`,
        prUrl: null,
        branch: null,
      });
      log("system", `Failed with exit code ${code}`);
    }

    onDone?.(task.id, code);
  });

  proc.on("error", (err) => {
    running.delete(task.id);
    updateTaskResult(task.id, {
      status: "failed",
      result: err.message,
      prUrl: null,
      branch: null,
    });
    log("system", `Process error: ${err.message}`);
    onDone?.(task.id, 1);
  });

  return proc;
}

/** Stop a running task */
export function stopTask(taskId) {
  const proc = running.get(taskId);
  if (proc) {
    proc.kill("SIGTERM");
    running.delete(taskId);
    updateTaskStatus(taskId, "failed");
    appendLog(taskId, "system", "Stopped by user");
  }
}

/** Check if a task is currently running */
export function isRunning(taskId) {
  return running.has(taskId);
}

function buildPrompt(task) {
  return `You are an autonomous coding agent working on the project at ${task.project}.

## Task: ${task.title}

${task.spec}

## Instructions
1. First, read AGENTS.md or CLAUDE.md if they exist in the project root
2. Create a new git branch for this task: task-${task.id}
3. Implement the changes described above
4. Run the verification script if available: /home/ubuntu/pilot/harness/scripts/verify.sh ${task.project}
5. If verification fails, fix the issues and retry
6. When done, commit your changes and open a PR using \`gh pr create\`
7. Include test results and any relevant screenshots as evidence in the PR body

## Quality requirements
- All type checks must pass
- All existing tests must pass
- New functionality should have tests if the project has a test framework
- Follow existing code patterns and conventions
- One logical change per commit`;
}

function extractPrUrl(output) {
  const match = output.match(/https:\/\/github\.com\/[^\s]+\/pull\/\d+/);
  return match?.[0] || null;
}

function extractBranch(output) {
  const match = output.match(/(?:branch|checkout -b|switch -c)\s+(\S+)/);
  return match?.[1] || null;
}
