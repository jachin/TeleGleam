import gleam/erlang/process
import gleam/option.{Some}
import harbinger
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
    logger: harbinger.Harbinger,
    bot_token: telegram.BotToken,
    chat_id: telegram.ChatId,
  )
}

fn init(
  logger: harbinger.Harbinger,
  bot_token: telegram.BotToken,
  chat_id: telegram.ChatId,
  media: List(media.Media),
) -> fn() -> #(Model, List(fn() -> Msg)) {
  let model =
    Model(media: media, logger: logger, bot_token: bot_token, chat_id: chat_id)
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
  ui.box([ui.text("Hello!")], Some("TeleGleam"))
  |> ui.align(style.Center, _)
  |> layout.center(style.Px(50), style.Px(12))
}

pub fn main(
  logger: harbinger.Harbinger,
  bot_token: telegram.BotToken,
  chat_id: telegram.ChatId,
  media: List(media.Media),
) {
  let exit = process.new_subject()
  let assert Ok(_actor) =
    shore.spec(
      init: init(logger, bot_token, chat_id, media),
      update:,
      view:,
      exit:,
      keybinds: shore.default_keybinds(),
      redraw: shore.on_timer(16),
    )
    |> shore.start
  exit |> process.receive_forever
}
