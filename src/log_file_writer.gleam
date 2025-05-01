//// This file is almost complely copied out of the flash module.
//// I wanted to log to a file (not the screen) and a lot of the
//// functions I wanted to copy the text_writer() function were
//// not public so I just copied them.
//// TODO: we should either switch to a different logging library
////       or wait for the flash module to include a file writer.

import flash
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/string
import gleam/string_tree
import gleam/time/calendar
import gleam/time/timestamp
import simplifile

fn unique_by(list, predicate) {
  case list {
    [] -> []
    [first, ..rest] -> [
      first,
      ..unique_by(
        list.filter(rest, fn(next) { predicate(first, next) }),
        predicate,
      )
    ]
  }
}

fn prepare_attrs(attrs: List(flash.Attr)) {
  attrs
  |> list.filter(fn(attr) {
    case attr {
      flash.GroupAttr(_, value) -> value != []
      _ -> True
    }
  })
  |> list.reverse
  |> unique_by(fn(a, b) { a.key != b.key })
  |> list.sort(attr_compare)
  |> list.map(fn(attr) {
    case attr {
      flash.GroupAttr(key, value) -> flash.GroupAttr(key, prepare_attrs(value))
      _ -> attr
    }
  })
}

fn attr_compare(a: flash.Attr, b: flash.Attr) {
  let a_is_group = case a {
    flash.GroupAttr(_, _) -> True
    _ -> False
  }
  let b_is_group = case b {
    flash.GroupAttr(_, _) -> True
    _ -> False
  }

  case a_is_group, b_is_group {
    True, True -> string.compare(a.key, b.key)
    False, False -> string.compare(a.key, b.key)
    True, False -> order.Gt
    _, _ -> order.Lt
  }
}

fn attr_to_text(attr) {
  let from_strings = string_tree.from_strings

  case attr {
    flash.BoolAttr(key, value) ->
      from_strings([key, "=", bool.to_string(value)])
    flash.FloatAttr(key, value) ->
      from_strings([key, "=", float.to_string(value)])
    flash.GroupAttr(key, value) ->
      value
      |> list.map(fn(attr) {
        let key = string.join([key, attr.key], ".")

        attr_to_text(case attr {
          flash.BoolAttr(_, value) -> flash.BoolAttr(key, value)
          flash.FloatAttr(_, value) -> flash.FloatAttr(key, value)
          flash.GroupAttr(_, value) -> flash.GroupAttr(key, value)
          flash.StringAttr(_, value) -> flash.StringAttr(key, value)
          flash.IntAttr(_, value) -> flash.IntAttr(key, value)
        })
      })
      |> string_tree.join(with: " ")
    flash.IntAttr(key, value) -> from_strings([key, "=", int.to_string(value)])
    flash.StringAttr(key, value) -> from_strings([key, "=", value])
  }
}

pub fn text_log_file_writer(file_path: String) {
  fn(level: flash.Level, message: String, attrs: List(flash.Attr)) -> Nil {
    let message = string.pad_end(message, 45, " ")
    let level =
      flash.level_to_string(level)
      |> string.uppercase
      |> string.pad_end(to: 5, with: " ")

    let #(_, now) =
      timestamp.to_calendar(timestamp.system_time(), calendar.local_offset())
    let time_tree =
      string_tree.from_strings([
        string.pad_start(int.to_string(now.hours), 2, "0"),
        ":",
        string.pad_start(int.to_string(now.minutes), 2, "0"),
        ":",
        string.pad_start(int.to_string(now.seconds), 2, "0"),
      ])

    let attrs =
      attrs
      |> prepare_attrs
      |> list.map(attr_to_text)

    let _ =
      string_tree.join(
        [
          time_tree,
          string_tree.from_string(level),
          string_tree.from_string(message),
          ..attrs
        ],
        " ",
      )
      |> string_tree.to_string
      |> string.append("\n")
      |> simplifile.append(to: file_path)

    Nil
  }
}
