module sanic.uv.handle;

import std.string : toUpper;
import core.memory : GC;

extern (C) {
  enum uv_handle_type {
    UNKNOWN_HANDLE = 0,
    ASYNC,
    CHECK,
    FS_EVENT,
    FS_POLL,
    HANDLE,
    IDLE,
    NAMED_PIPE,
    POLL,
    PREPARE,
    PROCESS,
    STREAM,
    TCP,
    TIMER,
    TTY,
    UDP,
    SIGNAL,
    FILE,
    HANDLE_TYPE_MAX
  };

  struct uv_handle_t;

  alias uv_close_cb = void function(uv_handle_t* handle);

  size_t uv_handle_size(uv_handle_type);
  void uv_close(uv_handle_t*, uv_close_cb*);
}

T* createHandle(T)() {
  return cast(T*)GC.malloc(uv_handle_size(mixin(
    `uv_handle_type.` ~ toUpper(T.stringof)[3..$-2]
  )));
}

void freeHandle(T)(T p) {
  uv_close(cast(uv_handle_t*)p, null);
  GC.free(p);
}
