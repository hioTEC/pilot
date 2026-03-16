import express from "express";
import crypto from "crypto";
import { createTask, getTask, listTasks, updateTaskStatus, getLogs } from "./lib/db.js";
import { createSession } from "./lib/coordinator.js";
import { startTask, stopTask, isRunning } from "./lib/runner.js";
import { getManagedProjects } from "./lib/context.js";

const app = express();
const PORT = process.env.PORT || 3002;
const PASSWORD = process.env.PILOT_PASSWORD || "HioTech@2026";
const TOKEN = crypto.createHash("sha256").update(PASSWORD + "salt:pilot.hio.zone").digest("hex");

app.use(express.json());

// --- Auth ---

function checkAuth(req, res, next) {
  if (req.path === "/login") return next();
  const token = req.cookies?.pilot_auth;
  if (token === TOKEN) return next();
  if (req.path.startsWith("/api/")) return res.status(401).json({ error: "Unauthorized" });
  return res.redirect("/login");
}

// Cookie parser (minimal, no dependency)
app.use((req, _res, next) => {
  req.cookies = {};
  const header = req.headers.cookie || "";
  for (const pair of header.split(";")) {
    const [k, v] = pair.trim().split("=");
    if (k) req.cookies[k] = v;
  }
  next();
});

app.use(checkAuth);

app.get("/login", (_req, res) => {
  res.type("html").send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pilot - Login</title>
<style>
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0f172a;color:#e2e8f0;font-family:system-ui}
  .box{background:#1e293b;padding:2rem;border-radius:12px;width:320px}
  h1{font-size:1.5rem;margin:0 0 1.5rem}
  input{width:100%;padding:.75rem;border:1px solid #334155;border-radius:8px;background:#0f172a;color:#e2e8f0;font-size:1rem;box-sizing:border-box}
  button{width:100%;padding:.75rem;border:none;border-radius:8px;background:#6366f1;color:#fff;font-size:1rem;cursor:pointer;margin-top:1rem}
  button:hover{background:#4f46e5}
  .err{color:#f87171;font-size:.875rem;margin-top:.5rem}
</style></head><body>
<div class="box"><h1>Pilot</h1>
<form method="POST" action="/login">
  <input name="password" type="password" placeholder="Password" autofocus>
  <button type="submit">Enter</button>
</form></div></body></html>`);
});

app.post("/login", express.urlencoded({ extended: false }), (req, res) => {
  if (req.body.password === PASSWORD) {
    res.cookie("pilot_auth", TOKEN, {
      httpOnly: true, sameSite: "Strict", maxAge: 7 * 86400 * 1000, path: "/",
    });
    return res.redirect("/");
  }
  res.status(401).type("html").send("Wrong password. <a href='/login'>Retry</a>");
});

app.get("/logout", (_req, res) => {
  res.clearCookie("pilot_auth").redirect("/login");
});

// --- Static ---
app.use(express.static("public"));

// --- SSE: log streaming ---
const sseClients = new Map(); // taskId -> Set<res>

app.get("/api/tasks/:id/logs/stream", (req, res) => {
  const taskId = Number(req.params.id);
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
  res.write(":\n\n"); // keep-alive

  if (!sseClients.has(taskId)) sseClients.set(taskId, new Set());
  sseClients.get(taskId).add(res);

  req.on("close", () => {
    sseClients.get(taskId)?.delete(res);
  });
});

function broadcastLog(taskId, type, content) {
  const clients = sseClients.get(taskId);
  if (!clients) return;
  const data = JSON.stringify({ type, content, time: new Date().toISOString() });
  for (const res of clients) {
    res.write(`data: ${data}\n\n`);
  }
}

// --- API: Tasks ---

app.get("/api/tasks", (_req, res) => {
  res.json(listTasks());
});

app.get("/api/tasks/:id", (req, res) => {
  const task = getTask(Number(req.params.id));
  if (!task) return res.status(404).json({ error: "Not found" });
  res.json(task);
});

app.post("/api/tasks", (req, res) => {
  const { title, spec, project } = req.body;
  if (!title || !spec || !project) {
    return res.status(400).json({ error: "title, spec, and project are required" });
  }
  const task = createTask(title, spec, project);
  res.status(201).json(task);
});

app.post("/api/tasks/:id/start", (req, res) => {
  const task = getTask(Number(req.params.id));
  if (!task) return res.status(404).json({ error: "Not found" });
  if (task.status === "running") return res.status(409).json({ error: "Already running" });

  try {
    startTask(task, {
      onLog: broadcastLog,
      onDone: (id, code) => {
        const clients = sseClients.get(id);
        if (clients) {
          const data = JSON.stringify({ type: "done", code });
          for (const c of clients) c.write(`data: ${data}\n\n`);
        }
      },
    });
    res.json({ status: "started" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/api/tasks/:id/stop", (req, res) => {
  stopTask(Number(req.params.id));
  res.json({ status: "stopped" });
});

app.post("/api/tasks/:id/status", (req, res) => {
  const { status } = req.body;
  if (!["todo", "done", "failed"].includes(status)) {
    return res.status(400).json({ error: "Invalid status" });
  }
  const task = updateTaskStatus(Number(req.params.id), status);
  res.json(task);
});

app.get("/api/tasks/:id/logs", (req, res) => {
  const sinceId = Number(req.query.since) || 0;
  res.json(getLogs(Number(req.params.id), sinceId));
});

// --- API: Coordinator chat ---
const sessions = new Map(); // sessionId -> chat session

app.post("/api/chat/start", (req, res) => {
  const { project } = req.body;
  if (!project) return res.status(400).json({ error: "project path required" });

  const sessionId = crypto.randomUUID();
  const session = createSession(project);
  sessions.set(sessionId, session);

  // Clean old sessions (keep max 10)
  if (sessions.size > 10) {
    const oldest = sessions.keys().next().value;
    sessions.delete(oldest);
  }

  res.json({ sessionId });
});

app.post("/api/chat/send", async (req, res) => {
  const { sessionId, message } = req.body;
  const session = sessions.get(sessionId);
  if (!session) return res.status(404).json({ error: "Session not found. Start a new chat." });

  try {
    const result = await session.send(message);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- API: Projects ---

app.get("/api/projects", (_req, res) => {
  res.json(getManagedProjects());
});

// --- Start ---
app.listen(PORT, () => {
  console.log(`Pilot running on http://localhost:${PORT}`);
});
