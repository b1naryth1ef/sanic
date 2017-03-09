module sanic.loop;

import core.thread : Fiber;
import core.sync.mutex : Mutex;

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
  Scheduler scheduler;
  Fiber fiber;
  uint data = 0;
  void* ctx;

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
  static UVLoop _loop;

  /// Mode this scheduler is operating in, can be swapped on the fly
  SchedulerMode mode = SchedulerMode.FIFO;

  /// Coroutines that are a member of this scheduler
  Coroutine*[] coroutines;

  // used to wait for coroutines if we don't have any
  Mutex _waitForCoroutines;

  this() {}

  @property UVLoop loop() {
    if (!this._loop) this._loop = new UVLoop;
    return this._loop;
  }

  void add(Coroutine* coro) {
    // TODO scheduler may need to metadata here
    this.coroutines ~= coro;
    if (this._waitForCoroutines) this._waitForCoroutines.unlock();
  }

  void spawn(void delegate() f) {
    this.add(new Coroutine(this, new Fiber(f)));
  }

  void testSleep(ulong sleepms) {
    // todo: gc
    auto timer = new UVTimer(this.loop, () {
      this.add(currentCoroutine);
    }, sleepms);

    currentCoroutine.ctx = cast(void*)timer;

    Fiber.yield();
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

unittest {
  import std.stdio;
  auto sched = new Scheduler();

  sched.spawn(() {
    writefln("TEST");
    sched.testSleep(1000);
    writefln("WOW");
  });

  sched.runOnce();
  sched.runOnce();
}
