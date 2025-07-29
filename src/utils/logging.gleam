import gleam/list
import gleam/string
import logging

pub fn parse_string_to_log_level(
  str: String,
) -> Result(logging.LogLevel, String) {
  case string.uppercase(str) {
    "EMERGENCY" -> Ok(logging.Emergency)
    "ALERT" -> Ok(logging.Alert)
    "CRITICAl" -> Ok(logging.Critical)
    "ERROR" -> Ok(logging.Error)
    "WARNING" -> Ok(logging.Warning)
    "NOTICE" -> Ok(logging.Notice)
    "INFO" -> Ok(logging.Info)
    "DEBUG" -> Ok(logging.Debug)
    _ -> Error("Invalid logger level: " <> str)
  }
}

pub fn log_level_to_string(l: logging.LogLevel) -> String {
  case l {
    logging.Emergency -> "EMERGENCY"
    logging.Alert -> "ALERT"
    logging.Critical -> "CRITICAl"
    logging.Error -> "ERROR"
    logging.Warning -> "WARNING"
    logging.Notice -> "NOTICE"
    logging.Info -> "INFO"
    logging.Debug -> "DEBUG"
  }
}

pub fn log_levels_as_strings() {
  list.map(
    [
      logging.Emergency,
      logging.Alert,
      logging.Critical,
      logging.Error,
      logging.Warning,
      logging.Notice,
      logging.Info,
      logging.Debug,
    ],
    log_level_to_string,
  )
}
