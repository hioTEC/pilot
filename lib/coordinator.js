import { spawn } from "child_process";

/** Tools the coordinator can use (read-only exploration) */
const COORDINATOR_TOOLS = [
  "Read", "Glob", "Grep",
  "Bash(ls *)", "Bash(git log *)", "Bash(git diff *)", "Bash(git show *)",
  "Bash(cat *)", "Bash(head *)", "Bash(wc *)",
].join(",");

const SYSTEM_PROMPT = `You are the **Pilot Coordinator** — a project management assistant for an autonomous AI development system.

## Your role
- Help the user (an ENFP product thinker, software engineering newcomer) turn vague ideas into well-structured task specifications
- ACTIVELY explore the codebase using your tools (Read, Grep, Glob) to understand the current state before making recommendations
- Validate that proposed tasks align with the project's architecture and conventions
- Ask 2-3 focused clarifying questions when a task idea is ambiguous
- When ready, produce a structured Task Spec

## Your style
- Respond in Chinese (with English technical terms where appropriate)
- Be concise and direct
- Present 2-3 options at decision points
- Focus on architecture and logic, not implementation details
- When the user describes something vague, explore the code first, then ask targeted questions

## When creating a Task Spec
After gathering enough information, output a structured spec in this exact format:

\`\`\`task-spec
{
  "title": "简洁的任务标题",
  "spec": "详细的任务描述，包含：\\n1. 目标（要达成什么）\\n2. 范围（涉及哪些模块/文件）\\n3. 具体步骤\\n4. 验收标准",
  "project": "project-name",
  "acceptance_criteria": [
    "criterion 1",
    "criterion 2"
  ]
}
\`\`\`

Only output the task-spec block when the user confirms they want to create the task. Before that, discuss and refine.`;

/**
 * Create a coordinator chat session using claude -p.
 * Each session tracks a Claude session ID for multi-turn conversation via --resume.
 */
export function createSession(projectPath) {
  let sessionId = null;

  return {
    /**
     * Send a message to the coordinator.
     * Returns { text, taskSpec, toolCalls } via streaming callback.
     * onChunk(chunk) is called for each stream-json line.
     */
    send(message, onChunk) {
      return new Promise((resolve, reject) => {
        const args = [
          "-p", message,
          "--output-format", "stream-json",
          "--allowedTools", COORDINATOR_TOOLS,
          "--max-turns", "30",
        ];

        // First message: set system prompt. Subsequent: resume session.
        if (sessionId) {
          args.push("--resume", sessionId);
        } else {
          args.push("--append-system-prompt", SYSTEM_PROMPT);
        }

        const proc = spawn("claude", args, {
          cwd: projectPath,
          env: { ...process.env, CLAUDE_CODE_DISABLE_CRON: "1" },
          stdio: ["pipe", "pipe", "pipe"],
        });

        let fullText = "";
        let buffer = "";
        const toolCalls = [];

        proc.stdout.on("data", (data) => {
          buffer += data.toString();
          // Parse NDJSON lines
          const lines = buffer.split("\n");
          buffer = lines.pop(); // keep incomplete last line

          for (const line of lines) {
            if (!line.trim()) continue;
            try {
              const event = JSON.parse(line);
              processEvent(event);
              onChunk?.(event);
            } catch { /* skip malformed lines */ }
          }
        });

        function processEvent(event) {
          // Capture session ID from init message
          if (event.type === "system" && event.session_id) {
            sessionId = event.session_id;
          }

          // Collect assistant text
          if (event.type === "assistant" && event.message?.content) {
            for (const block of event.message.content) {
              if (block.type === "text") {
                fullText += block.text;
              }
              if (block.type === "tool_use") {
                toolCalls.push({
                  tool: block.name,
                  input: summarizeInput(block.input),
                });
              }
            }
          }
        }

        proc.stderr.on("data", () => {}); // ignore stderr

        proc.on("close", (code) => {
          // Process remaining buffer
          if (buffer.trim()) {
            try {
              const event = JSON.parse(buffer);
              processEvent(event);
              onChunk?.(event);
            } catch { /* ignore */ }
          }

          if (code === 0 || fullText) {
            resolve({
              text: fullText,
              taskSpec: extractTaskSpec(fullText),
              toolCalls,
            });
          } else {
            reject(new Error(`Coordinator exited with code ${code}`));
          }
        });

        proc.on("error", (err) => reject(err));
      });
    },
  };
}

/** Summarize tool input for display (avoid showing full file contents) */
function summarizeInput(input) {
  if (!input) return "";
  if (typeof input === "string") return input.slice(0, 200);
  if (input.file_path) return input.file_path;
  if (input.pattern) return `pattern: ${input.pattern}`;
  if (input.command) return input.command.slice(0, 150);
  return JSON.stringify(input).slice(0, 200);
}

/** Extract a task-spec JSON block from coordinator response */
function extractTaskSpec(text) {
  const match = text.match(/```task-spec\s*\n([\s\S]*?)\n```/);
  if (!match) return null;
  try {
    return JSON.parse(match[1]);
  } catch {
    return null;
  }
}
