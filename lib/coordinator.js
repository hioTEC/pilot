import { GoogleGenerativeAI } from "@google/generative-ai";
import { readFileSync } from "fs";
import { loadProjectContext } from "./context.js";

const MODEL = process.env.GEMINI_MODEL || "gemini-2.5-pro-preview-03-25";

let genAI = null;

function getClient() {
  if (genAI) return genAI;
  const apiKey =
    process.env.GEMINI_API_KEY ||
    extractKeyFromEnv("/home/ubuntu/math-question-bank/.env.local");
  if (!apiKey) throw new Error("No GEMINI_API_KEY found");
  genAI = new GoogleGenerativeAI(apiKey);
  return genAI;
}

function extractKeyFromEnv(envPath) {
  try {
    const content = readFileSync(envPath, "utf-8");
    const match = content.match(/GEMINI_API_KEY=(.+)/);
    return match?.[1]?.trim() || null;
  } catch {
    return null;
  }
}

const SYSTEM_PROMPT = `You are the **Pilot Coordinator** — a project management assistant for an autonomous AI development system.

## Your role
- Help the user (an ENFP product thinker, software engineering newcomer) turn vague ideas into well-structured task specifications
- Validate that proposed tasks align with the project's architecture and conventions
- Ask 2-3 focused clarifying questions when a task idea is ambiguous
- When ready, produce a structured Task Spec

## Your style
- Respond in Chinese (with English technical terms where appropriate)
- Be concise and direct
- Present 2-3 options at decision points
- Focus on architecture and logic, not implementation details

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
 * Create a coordinator chat session for a specific project.
 * Returns a stateful chat object that maintains conversation history.
 */
export function createSession(projectPath) {
  const client = getClient();
  const model = client.getGenerativeModel({
    model: MODEL,
    systemInstruction:
      SYSTEM_PROMPT +
      "\n\n## Project Context\n" +
      loadProjectContext(projectPath),
  });

  const chat = model.startChat({ history: [] });

  return {
    async send(message) {
      const result = await chat.sendMessage(message);
      const text = result.response.text();
      return { text, taskSpec: extractTaskSpec(text) };
    },
  };
}

/**
 * Extract a task-spec JSON block from coordinator response, if present.
 */
function extractTaskSpec(text) {
  const match = text.match(/```task-spec\s*\n([\s\S]*?)\n```/);
  if (!match) return null;
  try {
    return JSON.parse(match[1]);
  } catch {
    return null;
  }
}
