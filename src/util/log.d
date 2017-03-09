module sanic.util.log;

import std.stdio : writeln;
import std.format : format;
import std.datetime : Clock, UTC, SysTime, DateTime;
import std.concurrency : thisTid;

enum LogLevel : string {
  TRACE = "TRACE",
  DEBUG = "DEBUG",
  INFO = "INFO",
  ERROR = "ERROR",
  FATAL = "FATAL",
  SCOPE = "SCOPE",
}

interface Writer {
  void write(string line);
}

class StdoutLogWriter : Writer {
  void write(string line) {
    writeln(line);
  }
}

mixin template Loggable() {
  void trace(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    this.log!(LogLevel.TRACE)(args, line, file);
  }

  void dbg(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    this.log!(LogLevel.DEBUG)(args, line, file);
  }

  void info(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    this.log!(LogLevel.INFO)(args, line, file);
  }

  void error(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    this.log!(LogLevel.ERROR)(args, line, file);
  }

  void fatal(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    this.log!(LogLevel.FATAL)(args, line, file);
    panic();
  }
}

// +1000000 [INFO] <1331> test.d:33 - This is a test log line
class Logger {
  mixin Loggable;

  LogLevel level;
  Writer[] writers;

  this() {
    debug {
      this.level = LogLevel.DEBUG;
    } else {
      this.level = LogLevel.INFO;
    }

    this.writers ~= new StdoutLogWriter;
  }

  string formatTime(SysTime time) {
    const auto dt = cast(DateTime)time;
    const auto fsec = time.fracSecs.total!"msecs";

    return format("%04d-%02d-%02dT%02d:%02d:%02d.%03d",
      dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
      fsec);
  }

  string finalFormat(string level, string msg, int line, string file) {
    return format(
      "%s %s [%s] %s:%s - %s",
      this.formatTime(Clock.currTime(UTC())),
      &thisTid,
      level,
      file,
      line,
      msg
    );
  }

  void log(LogLevel level, Args...)(auto ref Args args, int line = __LINE__, string file = __FILE__) {
    if (this.level > level) return;

    string message = this.finalFormat(level, format(args), line, file);

    foreach (w; this.writers) {
      w.write(message);
    }
  }

  ScopedLogger scoped(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    return ScopedLogger(this, this.finalFormat(LogLevel.SCOPE, format(args), line, file));
  }
}

struct ScopedLogger {
  mixin Loggable;
  Logger logger;

  string[] messages;

  this(Logger logger, string msg = "") {
    this.logger = logger;

    if (msg) {
      this.messages ~= msg;
    }
  }

  void opCall(int line = __LINE__, string file = __FILE__, Args...)(auto ref Args args) {
    this.messages ~= "  " ~ format("%s:%s - %s", file, line, format(args));
  }

  void commit() {
    foreach (w; this.logger.writers) {
      foreach (msg; this.messages) {
        w.write(msg);
      }
    }
    this.messages = [];
  }

  ~this() {
    this.commit();
  }
}

public __gshared Logger log = new Logger;
