module sanic.loop;

import std.stdio;

import core.thread : Fiber;
import core.sync.mutex : Mutex;

import sanic.util.log;
import sanic.uv.loop : UVLoop;
import sanic.uv.timer : UVTimer;

enum SchedulerMode {
  FIFO, // FIFO scheduler provides _even_ but not _fair_ scheduling
  PRIO, // PRIO scheduler provides priority based scheduling
  COST, // COST scheduler provides _fair_ but not _even_ scheduling
}

/**
  A coroutine is a single, cooperative fiber.
*/
struct Coroutine {
  EventLoop loop;
  Fiber fiber;
  void* ctx;

  void run() {
    log.dbg("[C%s] run", &this);
    currentCoroutine = &this;
    this.fiber.call();
  }

  void yield() {
    log.dbg("[C%s] yield", &this);
    currentCoroutine = null;
    Fiber.yield();
  }
}

/// The current coroutine
static Coroutine* currentCoroutine;

/// The automatic event loop for this thread, if created
static EventLoop currentThreadLoop;

EventLoop getLoop() {
  if (!currentThreadLoop) currentThreadLoop = new EventLoop;
  return currentThreadLoop;
}

/**
  The EventLoop is the base abstraction of interacting with sanic. It manages
  all the scheduling and execution of coroutines in a single thread.
*/
class EventLoop {
  /// The UV Loop for this eventloop.
  UVLoop loop;

  /// Mode this scheduler is operating in, can be swapped on the fly
  SchedulerMode mode = SchedulerMode.FIFO;

  /// Coroutines that are a member of this scheduler
  Coroutine*[] coroutines;

  // used to wait for coroutines if we don't have any
  Mutex _waitForCoroutines;

  this() {
    this.loop = new UVLoop;
  }

  /// Schedules a coroutine
  void schedule(Coroutine* coro) {
    log.dbg("[C%s] schedule", coro);
    // TODO scheduler may need to metadata here
    this.coroutines ~= coro;
    if (this._waitForCoroutines) this._waitForCoroutines.unlock();
  }

  Coroutine* spawn(void delegate() f, bool schedule = true) {
    auto coro = new Coroutine(this, new Fiber(f));
    log.dbg("[C%s] spawn", coro);
    if (schedule) this.schedule(coro);
    return coro;
  }

  /// Runs the event loop until termination
  void runForever() {
    while (true) {
      if (this.coroutines.length == 0) {
        this._waitForCoroutines = new Mutex;
      }

      if (this._waitForCoroutines) {
        this._waitForCoroutines.lock();
        destroy(this._waitForCoroutines);
      }

      this.runOnce();
    }
  }

  /// Runs the event loop for a single iteration
  void runOnce() {
    log.dbg("Running event loop once in %s", this.mode);
    final switch (this.mode) {
      case SchedulerMode.FIFO:
        this.runOnceFIFO();
        break;
      case SchedulerMode.PRIO:
        this.runOncePRIO();
        break;
      case SchedulerMode.COST:
        this.runOnceCOST();
        break;
    }

    this.loop.runOnce();
  }

  private void runOnceFIFO() {
    Coroutine*[] scheduled = this.coroutines;

    this.coroutines.length = 0;

    log.dbg("FIFO on %s coros", scheduled.length);
    foreach (coro; scheduled) {
      coro.run();
    }
  }

  private void runOncePRIO() {
    throw new Exception("Not Implementted");
  }

  private void runOnceCOST() {
    throw new Exception("Not Implementted");
  }
}
