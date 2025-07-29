import gleam/erlang/process
import gleam/list
import gleam/option.{Some}
import media
import shore
import shore/layout
import shore/style
import shore/ui
import telegram

pub type Msg {
  RequestFileMetaData
  ReceivedFileMetaData
  UploadGallery
  UploadGalleryResponse
}

pub type Model {
  Model(
    media: List(media.Media),
    bot_token: telegram.BotToken,
    chat_id: telegram.ChatId,
  )
}

fn init(
  bot_token: telegram.BotToken,
  chat_id: telegram.ChatId,
  media: List(media.Media),
) -> fn() -> #(Model, List(fn() -> Msg)) {
  let model = Model(media: media, bot_token: bot_token, chat_id: chat_id)
  let cmds = []
  fn() { #(model, cmds) }
}

pub fn update(model: Model, msg: Msg) -> #(Model, List(fn() -> Msg)) {
  case msg {
    RequestFileMetaData -> #(model, [])
    ReceivedFileMetaData -> #(model, [])
    UploadGallery -> #(model, [])
    UploadGalleryResponse -> #(model, [])
  }
}

pub fn view(model: Model) {
  ui.box(
    [
      ui.table(
        style.Pct(100),
        model.media |> list.map(fn(m) { [m.caption, m.file_path] }),
      ),
    ],
    Some("TeleGleam"),
  )
  |> ui.align(style.Center, _)
  |> layout.center(style.Pct(80), style.Pct(80))
}

pub fn main(
  bot_token: telegram.BotToken,
  chat_id: telegram.ChatId,
  media: List(media.Media),
) {
  let exit = process.new_subject()
  let assert Ok(_actor) =
    shore.spec(
      init: init(bot_token, chat_id, media),
      update:,
      view:,
      exit:,
      keybinds: shore.default_keybinds(),
      redraw: shore.on_timer(16),
    )
    |> shore.start
  exit |> process.receive_forever
}
