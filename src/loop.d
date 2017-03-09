module sanic.loop;

import core.thread : Fiber;
import core.sync.mutex : Mutex;

enum SchedulerMode {
  FIFO, // FIFO scheduler provides _even_ but not _fair_ scheduling
  PRIO, // PRIO scheduler provides priority based scheduling
  COST, // COST scheduler provides _fair_ but not _even_ scheduling
}

/**
  A coroutine is a single, cooperative fiber.
*/
struct Coroutine {
  Scheduler scheduler;
  Fiber fiber;
  uint data;

  void run() {
    currentCoroutine = &this;
    this.fiber.call();
  }
}

/// The current coroutine
static Coroutine* currentCoroutine;

/**
  The scheduler is our base building block for fiber-based async programming. It
  has knowledge about all the fibers in our current thread, and handles scheduling
  them fairly.
*/
class Scheduler {
  /// Mode this scheduler is operating in, can be swapped on the fly
  SchedulerMode mode = SchedulerMode.FIFO;

  /// Coroutines that are a member of this scheduler
  Coroutine[] coroutines;

  // used to wait for coroutines if we don't have any
  Mutex _waitForCoroutines;

  this() {}

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
  }

  private void runOnceFIFO() {
    foreach (coro; this.coroutines) {
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

unittest {
  auto sched = new Scheduler();
  sched.runOnce();
}
