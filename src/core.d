module sanic.core;

import std.stdio;

import core.thread : Fiber;
import sanic.loop : getLoop, Coroutine, currentCoroutine;
import sanic.uv.timer : UVTimer;

/// Sleep the fiber for some time (in milliseconds).
void sleep(ulong ms) {
  assert(currentCoroutine);

  auto current = currentCoroutine;
  new UVTimer(getLoop().loop, () {
    getLoop().schedule(current);
  }, ms);

  currentCoroutine.yield();
}

/// Yield this iteration of the fiber, it will be rescheduled and reran on the
//   next eventloop iteration.
void yield() {
  getLoop().schedule(currentCoroutine);
  currentCoroutine.yield();
}

/// Spawns a coroutine
Coroutine* spawn(void delegate() dg) {
  return getLoop().spawn(dg);
}

void runLoopForever() {
  getLoop().runForever();
}

void runLoopOnce() {
  getLoop().runOnce();
}

unittest {
  import sanic.util.log;
  auto log = log.scoped("sanic/core");
  scope (exit) log.commit();

  spawn(() {
    log("Coro1 completed");
  });

  spawn(() {
    sleep(250);
    log("Coro2 completed");
  });

  spawn(() {
    sleep(500);
    log("Coro3 completed");
  });

  runLoopOnce();
  runLoopOnce();
  runLoopOnce();
}
