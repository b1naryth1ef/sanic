module sanic.uv.timer;

import sanic.uv.loop : UVLoop, uv_loop_t;
import sanic.uv.handle : createHandle, freeHandle;

extern (C) {
  struct uv_timer_t {
    void* data;
  };

  alias uv_timer_cb = void function(uv_timer_t* handle);

  int uv_timer_init(uv_loop_t*, uv_timer_t*);
  int uv_timer_start(uv_timer_t*, uv_timer_cb, ulong timeout, ulong repeat);
  int uv_timer_stop(uv_timer_t*);

  void uv_timer_set_repeat(uv_timer_t*, ulong);
  ulong uv_timer_get_repeat(uv_timer_t*);

  void handleTimerCallback(uv_timer_t* handle) {
    (cast(UVTimer)(handle.data)).callback();
  }
}

class UVTimer {
  uv_timer_t* timer;
  void delegate() callback;

  int wtf = 1;

  this(UVLoop loop, void delegate() callback) {
    this.callback = callback;
    this.timer = createHandle!uv_timer_t;
    uv_timer_init(loop.loop, this.timer);
    this.timer.data = cast(void*)this;
  }

  this(UVLoop loop, void delegate() callback, ulong timeout) {
    this(loop, callback);
    this.start(timeout);
  }

  this(UVLoop loop, void delegate() callback, ulong timeout, ulong repeat) {
    this(loop, callback);
    this.start(timeout, repeat);
  }

  ~this() {
    freeHandle(this.timer);
  }

  void start(ulong timeout, ulong repeat = 0) {
    uv_timer_start(this.timer, &handleTimerCallback, timeout, repeat);
  }

  @property ulong repeat() {
    return uv_timer_get_repeat(this.timer);
  }

  @property void repeat(ulong value) {
    uv_timer_set_repeat(this.timer, value);
  }
}

unittest {
  import sanic.util.log;
  auto log = log.scoped("uv/timer");
  scope (exit) log.commit();

  auto loop = new UVLoop;

  auto t1 = new UVTimer(loop, () {
    log("T1 completed");
  }, 100);

  auto t2 = new UVTimer(loop, () {
    log("T2 completed");
  }, 150);

  auto t3 = new UVTimer(loop, () {
    log("T3 completed");
    loop.stop();
  }, 200);

  log("Starting loop...");
  loop.run();

  destroy(loop);
}
