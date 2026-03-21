import { listTasks } from "./db.js";
import { startTask, isRunning, stopTask } from "./runner.js";

const POLL_INTERVAL = 5000;

/**
 * Auto-queue engine.
 * Polls for "todo" tasks and starts them when a slot is free.
 * Manages timeouts to kill hung processes.
 * Respects task priority and dependencies.
 */
class TaskQueue {
  constructor() {
    this.enabled = false;
    this.maxConcurrent = 1;
    this.timer = null;
    this.taskTimeouts = new Map();
    this.callbacks = {};
  }

  /** Initialize with callbacks and start polling. */
  init(callbacks) {
    this.callbacks = callbacks;
    this.timer = setInterval(() => this.tick(), POLL_INTERVAL);
  }

  /** Main loop: start next eligible task if a slot is free. */
  tick() {
    if (!this.enabled) return;

    const tasks = listTasks();
    const runningCount = tasks.filter((t) => t.status === "running").length;
    if (runningCount >= this.maxConcurrent) return;

    const next = this.pickNext(tasks);
    if (next) this.launch(next);
  }

  /** Pick the highest-priority eligible task. */
  pickNext(tasks) {
    return tasks
      .filter((t) => t.status === "todo")
      .filter((t) => {
        if (!t.depends_on) return true;
        const dep = tasks.find((d) => d.id === t.depends_on);
        return dep && (dep.status === "done" || dep.status === "passed");
      })
      .sort((a, b) => (b.priority || 0) - (a.priority || 0))[0] || null;
  }

  /** Start a task with timeout watchdog. */
  launch(task) {
    const { onLog, onDone, onNotify } = this.callbacks;

    try {
      startTask(task, {
        onLog,
        onDone: (id, code) => {
          const handle = this.taskTimeouts.get(id);
          if (handle) {
            clearTimeout(handle);
            this.taskTimeouts.delete(id);
          }
          onDone?.(id, code);
          onNotify?.(id, code === 0 ? "passed" : "failed", task.title);
        },
      });

      // Timeout watchdog
      const minutes = task.timeout_minutes || 30;
      const handle = setTimeout(() => {
        if (isRunning(task.id)) {
          onLog?.(task.id, "system", `Task timed out after ${minutes} minutes. Killing process.`);
          stopTask(task.id);
          onNotify?.(task.id, "timeout", task.title);
        }
      }, minutes * 60 * 1000);
      this.taskTimeouts.set(task.id, handle);

      onNotify?.(task.id, "started", task.title);
    } catch (err) {
      onLog?.(task.id, "system", `Queue failed to start task: ${err.message}`);
    }
  }

  setEnabled(val) {
    this.enabled = !!val;
  }

  setMaxConcurrent(val) {
    this.maxConcurrent = Math.max(1, Math.min(val, 5));
  }

  getStatus() {
    const tasks = listTasks();
    return {
      enabled: this.enabled,
      maxConcurrent: this.maxConcurrent,
      running: tasks.filter((t) => t.status === "running").length,
      queued: tasks.filter((t) => t.status === "todo").length,
    };
  }

  shutdown() {
    if (this.timer) clearInterval(this.timer);
    for (const [, handle] of this.taskTimeouts) clearTimeout(handle);
  }
}

export const queue = new TaskQueue();
