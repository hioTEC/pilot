import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { resolve, relative, join } from "path";

/**
 * Load project context for the Gemini coordinator.
 * Reads memory files, architecture docs, and project structure
 * to give the coordinator a solid understanding of the codebase.
 */
export function loadProjectContext(projectPath) {
  const sections = [];

  // 1. User-level memory
  const userMemory = tryRead(
    resolve("/home/ubuntu/.claude/projects/-home-ubuntu/memory/MEMORY.md")
  );
  if (userMemory) sections.push({ title: "User Memory (global)", content: userMemory });

  const userProfile = tryRead(
    resolve("/home/ubuntu/.claude/projects/-home-ubuntu/memory/user_profile.md")
  );
  if (userProfile) sections.push({ title: "User Profile", content: userProfile });

  // 2. Project-level memory
  const projectSlug = projectPath.replace(/\//g, "-").replace(/^-/, "");
  const projectMemoryDir = `/home/ubuntu/.claude/projects/${projectSlug}/memory`;
  const projectMemory = tryRead(resolve(projectMemoryDir, "MEMORY.md"));
  if (projectMemory) sections.push({ title: "Project Memory", content: projectMemory });

  // 3. Architecture docs
  const docFiles = [
    "CLAUDE.md", "AGENTS.md",
    "docs/roadmap.md", "docs/feature-plan.md",
    "docs/multi-subject-architecture.md",
  ];
  for (const f of docFiles) {
    const content = tryRead(resolve(projectPath, f));
    if (content) sections.push({ title: f, content: truncate(content, 6000) });
  }

  // 4. File tree (top 2 levels of src/)
  const srcDir = resolve(projectPath, "src");
  if (existsSync(srcDir)) {
    const tree = listFiles(srcDir, 2).map((f) => relative(projectPath, f)).join("\n");
    sections.push({ title: "Source file tree (src/)", content: tree });
  }

  // 5. Pilot project config
  const pilotJson = tryRead(resolve("/home/ubuntu/pilot/pilot.json"));
  if (pilotJson) sections.push({ title: "Pilot managed projects", content: pilotJson });

  return sections
    .map((s) => `--- ${s.title} ---\n${s.content}`)
    .join("\n\n");
}

/** List all managed projects from pilot.json */
export function getManagedProjects() {
  try {
    const raw = readFileSync(
      resolve("/home/ubuntu/pilot/pilot.json"),
      "utf-8"
    );
    return JSON.parse(raw).projects || [];
  } catch {
    return [];
  }
}

function tryRead(path) {
  try {
    return existsSync(path) ? readFileSync(path, "utf-8") : null;
  } catch {
    return null;
  }
}

/** Recursively list files up to maxDepth levels */
function listFiles(dir, maxDepth, depth = 0) {
  if (depth >= maxDepth) return [];
  const results = [];
  try {
    for (const entry of readdirSync(dir)) {
      if (entry.startsWith(".") || entry === "node_modules") continue;
      const full = join(dir, entry);
      const stat = statSync(full);
      if (stat.isFile()) results.push(full);
      else if (stat.isDirectory()) results.push(...listFiles(full, maxDepth, depth + 1));
      if (results.length > 80) break;
    }
  } catch { /* skip unreadable dirs */ }
  return results;
}

function truncate(text, maxLen) {
  return text.length > maxLen ? text.slice(0, maxLen) + "\n...(truncated)" : text;
}
