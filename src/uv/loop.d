module sanic.uv.loop;

import core.memory : GC;

extern (C) {
  enum uv_run_mode {
    UV_RUN_DEFAULT = 0,
    UV_RUN_ONCE,
    UV_RUN_NOWAIT
  };

  struct uv_loop_t {
    void* data;
  };

  size_t uv_loop_size();

  int uv_loop_init(uv_loop_t*);
  int uv_loop_close(uv_loop_t*);
  uv_loop_t* uv_default_loop();

  int uv_run(uv_loop_t*, uv_run_mode);
  int uv_loop_alive(const uv_loop_t*);
  void uv_stop(uv_loop_t*);
  ulong uv_now(const uv_loop_t*);
}

enum UVRunMode {
  UV_RUN_DEFAULT = 0,
  UV_RUN_ONCE,
  UV_RUN_NOWAIT,
}

class UVLoop {
  uv_loop_t* loop;

  this() {
    this.loop = cast(uv_loop_t*)GC.malloc(uv_loop_size());
    uv_loop_init(this.loop);
  }

  ~this() {
    uv_loop_close(this.loop);
    GC.free(this.loop);
  }

  void run() {
    uv_run(this.loop, uv_run_mode.UV_RUN_DEFAULT);
  }

  void runOnce() {
    uv_run(this.loop, uv_run_mode.UV_RUN_ONCE);
  }

  void stop() {
    uv_stop(this.loop);
  }

  ulong now() {
    return uv_now(this.loop);
  }
}

unittest {
  auto loop = new UVLoop;
  loop.run();
  destroy(loop);
}
