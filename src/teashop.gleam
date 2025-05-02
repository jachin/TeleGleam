import teashop/command
import teashop/event
import teashop/internal/action

pub type App(model, msg, flags)

pub type Dispatch(msg) =
  fn(Action(msg)) -> Nil

pub opaque type Action(msg) {
  Action(action.InternalAction(msg))
}

@external(javascript, "./teashop.ffi.mjs", "setup")
pub fn app(
  init: fn(flags) -> #(model, command.Command(msg)),
  update: fn(model, event.Event(msg)) -> #(model, command.Command(msg)),
  view: fn(model) -> String,
) -> App(model, msg, flags)

@external(javascript, "./teashop.ffi.mjs", "run")
pub fn start(
  app: App(model, msg, flags),
  flags: flags,
) -> fn(Action(msg)) -> Nil

pub fn send(dispatch: Dispatch(msg), msg: msg) {
  dispatch(Action(action.Send(msg)))
}

pub fn quit(dispatch: Dispatch(msg)) {
  dispatch(Action(action.Shutdown))
}

pub fn set_window_title(dispatch: Dispatch(msg), title: String) {
  dispatch(Action(action.WindowTitle(title)))
}
