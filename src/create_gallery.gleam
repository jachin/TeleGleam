import gleam/erlang/process
import gleam/http/response
import gleam/httpc
import gleam/list
import gleam/option.{Some}
import glight.{info, logger}
import logging
import media
import shore
import shore/key
import shore/layout
import shore/style
import shore/ui
import telegram

pub fn upload_gallery(
  bot_token: telegram.BotToken,
  chat_id: telegram.ChatId,
  media: List(media.Media),
) -> fn() -> Msg {
  fn() {
    logger() |> info("upload_gallery")
    telegram.send_media_group(bot_token, chat_id, media)
    |> UploadGalleryResponse
  }
}

pub type Msg {
  RequestFileMetaData
  ReceivedFileMetaData
  UploadGallery
  UploadGalleryResponse(Result(response.Response(BitArray), httpc.HttpError))
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
  logging.log(logging.Debug, "Initialzing the create gallery app")

  let model = Model(media: media, bot_token: bot_token, chat_id: chat_id)
  let cmds = []
  fn() { #(model, cmds) }
}

pub fn update(model: Model, msg: Msg) -> #(Model, List(fn() -> Msg)) {
  case msg {
    RequestFileMetaData -> #(model, [])
    ReceivedFileMetaData -> #(model, [])
    UploadGallery -> {
      logging.log(logging.Debug, "update UploadGallery")
      #(model, [])
    }
    UploadGalleryResponse(_) -> #(model, [])
  }
}

pub fn view(model: Model) {
  ui.box(
    [
      ui.table(
        style.Pct(100),
        model.media |> list.map(fn(m) { [m.caption, m.file_path] }),
      ),
      ui.button("Send", key.Ctrl("s"), UploadGallery),
    ],
    Some("TeleGleam"),
  )
  |> ui.align(style.Center, _)
  |> layout.center(style.Pct(80), style.Pct(80))
}

pub fn main(
  logger_level: glight.LogLevel,
  bot_token: telegram.BotToken,
  chat_id: telegram.ChatId,
  media: List(media.Media),
) {
  glight.configure([glight.File("log.txt")])
  glight.set_log_level(logger_level)
  logger() |> info("starting the create_gallery app")
  let exit = process.new_subject()
  let assert Ok(_actor) =
    shore.spec(
      init: init(bot_token, chat_id, media),
      update:,
      view:,
      exit:,
      keybinds: shore.default_keybinds(),
      redraw: shore.on_update(),
    )
    |> shore.start
  exit |> process.receive_forever
}
