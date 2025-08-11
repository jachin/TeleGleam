import gleam/list
import gleam/string
import glight

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
