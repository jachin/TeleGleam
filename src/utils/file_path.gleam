import gleam/list
import gleam/string

pub fn basename_or_root(path: String) -> String {
  let normalized = string.replace(path, "\\", "/")

  // If it's just "/" (or multiple slashes), return "/"
  let only_slashes =
    normalized
    |> string.split(on: "/")
    |> list.all(fn(s) { s == "" })

  case only_slashes {
    True -> "/"
    False -> {
      let segments =
        normalized
        |> string.split(on: "/")
        |> list.filter(fn(s) { s != "" })

      case list.last(segments) {
        Ok(name) -> name
        Error(_) -> ""
      }
    }
  }
}
