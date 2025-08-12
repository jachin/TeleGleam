import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/string
import glight

pub type LoggerState =
  Dynamic

@external(erlang, "logger_preserve_ffi", "save_state")
pub fn save_state() -> LoggerState

@external(erlang, "logger_preserve_ffi", "restore_state")
pub fn restore_state(state: LoggerState) -> Nil

@external(erlang, "logger_preserve_ffi", "with_preserved_state")
pub fn with_preserved_state(f: fn() -> a) -> a

pub fn parse_string_to_log_level(str: String) -> Result(glight.LogLevel, String) {
  case string.uppercase(str) {
    "EMERGENCY" -> Ok(glight.Emergency)
    "ALERT" -> Ok(glight.Alert)
    "CRITICAl" -> Ok(glight.Critical)
    "ERROR" -> Ok(glight.Error)
    "WARNING" -> Ok(glight.Warning)
    "NOTICE" -> Ok(glight.Notice)
    "INFO" -> Ok(glight.Info)
    "DEBUG" -> Ok(glight.Debug)
    _ -> Error("Invalid logger level: " <> str)
  }
}

pub fn log_level_to_string(l: glight.LogLevel) -> String {
  case l {
    glight.Emergency -> "EMERGENCY"
    glight.Alert -> "ALERT"
    glight.Critical -> "CRITICAl"
    glight.Error -> "ERROR"
    glight.Warning -> "WARNING"
    glight.Notice -> "NOTICE"
    glight.Info -> "INFO"
    glight.Debug -> "DEBUG"
  }
}

pub fn log_levels_as_strings() {
  list.map(
    [
      glight.Emergency,
      glight.Alert,
      glight.Critical,
      glight.Error,
      glight.Warning,
      glight.Notice,
      glight.Info,
      glight.Debug,
    ],
    log_level_to_string,
  )
}

pub fn log(
  logger: dict.Dict(String, String),
  level: glight.LogLevel,
  message: String,
) {
  case level {
    glight.Emergency -> {
      glight.emergency(logger, message)
    }
    glight.Alert -> {
      glight.alert(logger, message)
    }
    glight.Critical -> {
      glight.critical(logger, message)
    }
    glight.Error -> {
      glight.error(logger, message)
    }
    glight.Warning -> {
      glight.warning(logger, message)
    }
    glight.Notice -> {
      glight.notice(logger, message)
    }
    glight.Info -> {
      glight.info(logger, message)
    }
    glight.Debug -> {
      glight.debug(logger, message)
    }
  }
}
