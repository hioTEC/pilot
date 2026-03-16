import { spawn, execSync } from "child_process";
import { existsSync, mkdirSync } from "fs";
import { appendLog, updateTaskResult, updateTaskStatus } from "./db.js";

const WORKTREE_BASE = "/home/ubuntu/.worktrees";

/** Track running processes so we can kill them if needed */
const running = new Map();

/** Maximum retry attempts (3 total = 1 initial + 2 retries) */
const MAX_ATTEMPTS = 3;

/** Default tool allowlist for Claude */
const ALLOWED_TOOLS = [
  "Read", "Edit", "Write", "Glob", "Grep",
  "Bash(npm *)", "Bash(npx *)", "Bash(git *)", "Bash(node *)",
  "Bash(ls *)", "Bash(mkdir *)", "Bash(cp *)", "Bash(mv *)",
  "Bash(cat *)", "Bash(pm2 *)",
  "Agent",
].join(",");

/**
 * Protected paths that Claude must not modify.
 * Used in the scope contract section of the prompt.
 */
const PROTECTED_PATHS = [
  ".env*",
  ".git/",
  "node_modules/",
  "*.lock",
  "*.db",
  "*.sqlite",
  "*.sqlite3",
];

/**
 * Start a Claude -p process for a task.
 * Streams output to DB logs and SSE listeners.
 * Supports automatic retry on failure (up to MAX_ATTEMPTS total).
 */
export function startTask(task, { onLog, onDone } = {}) {
  if (running.has(task.id)) {
    throw new Error(`Task ${task.id} is already running`);
  }

  updateTaskStatus(task.id, "running");

  // Set up worktree for isolated development
  const worktree = createWorktree(task);
  const workDir = worktree || task.project;

  // Create a git snapshot before starting so we can restore on retry
  const snapshot = createGitSnapshot(workDir);

  // Launch the first attempt
  runAttempt(task, { onLog, onDone, snapshot, attempt: 1, priorErrors: [], workDir, worktree });
}

/**
 * Run a single attempt of the task.
 * On failure, restores git state and retries with error context.
 */
function runAttempt(task, { onLog, onDone, snapshot, attempt, priorErrors, workDir, worktree }) {
  const prompt = buildPrompt(task, { attempt, priorErrors, workDir });

  const args = [
    "-p", prompt,
    "--output-format", "text",
    "--allowedTools", ALLOWED_TOOLS,
    "--max-turns", "200",
  ];

  const proc = spawn("claude", args, {
    cwd: workDir,
    env: { ...process.env, CLAUDE_CODE_DISABLE_CRON: "1" },
    stdio: ["pipe", "pipe", "pipe"],
  });

  running.set(task.id, proc);

  const log = (type, content) => {
    appendLog(task.id, type, content);
    onLog?.(task.id, type, content);
  };

  log("system", `Attempt ${attempt}/${MAX_ATTEMPTS} — Started claude process (PID: ${proc.pid})`);

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

    if (code === 0) {
      // Success
      const prUrl = extractPrUrl(output);
      const branch = extractBranch(output);

      updateTaskResult(task.id, {
        status: "passed",
        result: output.slice(-2000),
        prUrl,
        branch,
      });
      // Keep the worktree branch but remove the working directory
      removeWorktree(task.project, worktree, log);
      log("system", `Attempt ${attempt}/${MAX_ATTEMPTS} — Completed successfully${prUrl ? ` — PR: ${prUrl}` : ""}`);
      onDone?.(task.id, code);
    } else if (attempt < MAX_ATTEMPTS) {
      // Failed but can retry
      log("system", `Attempt ${attempt}/${MAX_ATTEMPTS} — Failed with exit code ${code}. Retrying...`);

      // Restore git state
      restoreGitState(workDir, log);

      // Collect error context from this attempt
      const errorTail = output.slice(-1500);
      const updatedErrors = [...priorErrors, {
        attempt,
        exitCode: code,
        errorOutput: errorTail,
      }];

      // Retry after a brief pause to avoid hammering
      setTimeout(() => {
        runAttempt(task, {
          onLog,
          onDone,
          snapshot,
          attempt: attempt + 1,
          priorErrors: updatedErrors,
          workDir,
          worktree,
        });
      }, 2000);
    } else {
      // All attempts exhausted
      removeWorktree(task.project, worktree, log);
      updateTaskResult(task.id, {
        status: "failed",
        result: `Exit code: ${code} (after ${attempt} attempts)\n${output.slice(-2000)}`,
        prUrl: null,
        branch: null,
      });
      log("system", `All ${MAX_ATTEMPTS} attempts exhausted. Task failed with exit code ${code}.`);
      onDone?.(task.id, code);
    }
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

/**
 * Create a git snapshot of the project's current state.
 * Returns the stash ref if changes exist, or null if clean.
 */
function createGitSnapshot(projectPath) {
  try {
    const ref = execSync("git stash create", {
      cwd: projectPath,
      encoding: "utf-8",
      timeout: 10000,
    }).trim();
    return ref || null;
  } catch {
    return null;
  }
}

/**
 * Restore git working tree to a clean state for retry.
 */
function restoreGitState(projectPath, log) {
  try {
    execSync("git checkout .", {
      cwd: projectPath,
      encoding: "utf-8",
      timeout: 10000,
    });
    log("system", "Git state restored for retry (git checkout .)");
  } catch (err) {
    log("system", `Warning: git restore failed: ${err.message}`);
  }
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

/**
 * Create a git worktree for isolated task development.
 * Path: ~/.worktrees/{project}-task-{id}-{date}
 * Branch: task-{id}
 * Returns the worktree path, or null if creation fails (e.g., not a git repo).
 */
function createWorktree(task) {
  const projectName = task.project.split("/").pop();
  const date = new Date().toISOString().slice(0, 10);
  const wtPath = `${WORKTREE_BASE}/${projectName}-task-${task.id}-${date}`;
  const branch = `task-${task.id}`;

  if (!existsSync(WORKTREE_BASE)) mkdirSync(WORKTREE_BASE, { recursive: true });

  try {
    execSync(`git worktree add "${wtPath}" -b "${branch}"`, {
      cwd: task.project,
      encoding: "utf-8",
      timeout: 15000,
    });
    return wtPath;
  } catch {
    // Fallback: branch may already exist, try without -b
    try {
      execSync(`git worktree add "${wtPath}" "${branch}"`, {
        cwd: task.project,
        encoding: "utf-8",
        timeout: 15000,
      });
      return wtPath;
    } catch {
      return null;
    }
  }
}

/**
 * Remove a worktree after task completion (success or final failure).
 * The branch is kept so the PR/commits remain accessible.
 */
function removeWorktree(projectPath, wtPath, log) {
  if (!wtPath) return;
  try {
    execSync(`git worktree remove "${wtPath}" --force`, {
      cwd: projectPath,
      encoding: "utf-8",
      timeout: 10000,
    });
    log?.("system", `Worktree removed: ${wtPath}`);
  } catch {
    // Non-fatal: worktree may already be gone
  }
}

function buildPrompt(task, { attempt = 1, priorErrors = [], workDir } = {}) {
  const isWorktree = workDir && workDir !== task.project;

  let prompt = `You are an autonomous coding agent working on the project.
${isWorktree ? `You are in an isolated git worktree at ${workDir} (branch: task-${task.id}).` : `Project path: ${task.project}.`}

## Task: ${task.title}

${task.spec}

## SCOPE CONTRACT
You must respect the following boundaries:

**Allowed modifications:** Files within the project's \`src/\` directory by default.
Other project files may be modified only if explicitly required by the task spec.

**Protected paths — DO NOT modify:**
${PROTECTED_PATHS.map((p) => `- \`${p}\``).join("\n")}

After completing your changes, verify your modifications comply with this contract:
\`\`\`
git diff --name-only
\`\`\`
If any changed file matches a protected path, revert it immediately with \`git checkout -- <file>\`.

## Instructions
1. First, read AGENTS.md or CLAUDE.md if they exist in the project root
${isWorktree ? "2. You are already on branch task-" + task.id + " — do NOT create a new branch" : "2. Create a new git branch for this task: task-" + task.id}
3. Implement the changes described above
4. Run the verification script if available: /home/ubuntu/pilot/harness/scripts/verify.sh .
5. If verification fails, fix the issues and retry
6. When done, commit your changes and open a PR using \`gh pr create\`
7. Include test results and any relevant screenshots as evidence in the PR body

## Quality requirements
- All type checks must pass
- All existing tests must pass
- New functionality should have tests if the project has a test framework
- Follow existing code patterns and conventions
- One logical change per commit`;

  // Append retry context if this is a retry attempt
  if (attempt > 1 && priorErrors.length > 0) {
    prompt += `\n\n## RETRY CONTEXT (Attempt ${attempt}/${MAX_ATTEMPTS})
Previous attempt(s) failed. Learn from these errors and avoid repeating them.
`;
    for (const err of priorErrors) {
      prompt += `\n### Attempt ${err.attempt} — Exit code ${err.exitCode}
\`\`\`
${err.errorOutput}
\`\`\`
`;
    }
    prompt += `\nFix the issues that caused the previous failure(s) before proceeding.`;
  }

  return prompt;
}

function extractPrUrl(output) {
  const match = output.match(/https:\/\/github\.com\/[^\s]+\/pull\/\d+/);
  return match?.[0] || null;
}

function extractBranch(output) {
  const match = output.match(/(?:branch|checkout -b|switch -c)\s+(\S+)/);
  return match?.[1] || null;
}
