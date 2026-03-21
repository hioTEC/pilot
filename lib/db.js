import Database from "better-sqlite3";
import { existsSync, mkdirSync } from "fs";
import { dirname } from "path";

const DB_PATH = new URL("../data/pilot.db", import.meta.url).pathname;

// Ensure data directory exists
const dir = dirname(DB_PATH);
if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

// Schema
db.exec(`
  CREATE TABLE IF NOT EXISTS tasks (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    title      TEXT NOT NULL,
    spec       TEXT NOT NULL,
    project    TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'todo',
    branch     TEXT,
    pr_url     TEXT,
    result     TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS task_logs (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id    INTEGER NOT NULL REFERENCES tasks(id),
    type       TEXT NOT NULL DEFAULT 'stdout',
    content    TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );
`);

// Migrations: add columns for queue support
try { db.exec("ALTER TABLE tasks ADD COLUMN priority INTEGER DEFAULT 0"); } catch { /* already exists */ }
try { db.exec("ALTER TABLE tasks ADD COLUMN depends_on INTEGER REFERENCES tasks(id)"); } catch { /* already exists */ }
try { db.exec("ALTER TABLE tasks ADD COLUMN timeout_minutes INTEGER DEFAULT 30"); } catch { /* already exists */ }

// Recovery: reset orphaned "running" tasks on startup (process died)
db.prepare(`UPDATE tasks SET status = 'todo' WHERE status = 'running'`).run();

// Prepared statements
const stmts = {
  createTask: db.prepare(`
    INSERT INTO tasks (title, spec, project, status, priority, depends_on, timeout_minutes) VALUES (?, ?, ?, ?, ?, ?, ?)
  `),
  updateTaskFields: db.prepare(`
    UPDATE tasks SET priority = ?, depends_on = ?, timeout_minutes = ?, updated_at = datetime('now') WHERE id = ?
  `),
  updateTaskSpec: db.prepare(`
    UPDATE tasks SET title = ?, spec = ?, status = ?, updated_at = datetime('now') WHERE id = ?
  `),
  getTask: db.prepare(`SELECT * FROM tasks WHERE id = ?`),
  listTasks: db.prepare(`SELECT * FROM tasks ORDER BY created_at DESC`),
  updateTask: db.prepare(`
    UPDATE tasks SET status = ?, updated_at = datetime('now') WHERE id = ?
  `),
  updateTaskResult: db.prepare(`
    UPDATE tasks SET status = ?, result = ?, pr_url = ?, branch = ?, updated_at = datetime('now') WHERE id = ?
  `),
  appendLog: db.prepare(`
    INSERT INTO task_logs (task_id, type, content) VALUES (?, ?, ?)
  `),
  getLogs: db.prepare(`
    SELECT * FROM task_logs WHERE task_id = ? ORDER BY id ASC
  `),
  getLogsSince: db.prepare(`
    SELECT * FROM task_logs WHERE task_id = ? AND id > ? ORDER BY id ASC
  `),
};

export function createTask(title, spec, project, status = "todo", { priority = 0, dependsOn = null, timeoutMinutes = 30 } = {}) {
  const info = stmts.createTask.run(title, spec, project, status, priority, dependsOn, timeoutMinutes);
  return stmts.getTask.get(info.lastInsertRowid);
}

export function updateTaskFields(id, { priority, dependsOn, timeoutMinutes }) {
  stmts.updateTaskFields.run(priority ?? 0, dependsOn ?? null, timeoutMinutes ?? 30, id);
  return stmts.getTask.get(id);
}

export function updateTaskSpec(id, title, spec, status = "todo") {
  stmts.updateTaskSpec.run(title, spec, status, id);
  return stmts.getTask.get(id);
}

export function getTask(id) {
  return stmts.getTask.get(id);
}

export function listTasks() {
  return stmts.listTasks.all();
}

export function updateTaskStatus(id, status) {
  stmts.updateTask.run(status, id);
  return stmts.getTask.get(id);
}

export function updateTaskResult(id, { status, result, prUrl, branch }) {
  stmts.updateTaskResult.run(status, result || null, prUrl || null, branch || null, id);
  return stmts.getTask.get(id);
}

export function appendLog(taskId, type, content) {
  stmts.appendLog.run(taskId, type, content);
}

export function getLogs(taskId, sinceId = 0) {
  return sinceId > 0
    ? stmts.getLogsSince.all(taskId, sinceId)
    : stmts.getLogs.all(taskId);
}

export default db;
