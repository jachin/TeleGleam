import flash
import gleam/javascript/promise
import gleam/list
import gleam/string
import media
import teashop/command
import teashop/event
import teashop/key
import telegram

pub type Model {
  Model(
    media: List(media.Media),
    logger: flash.Logger,
    bot_token: telegram.BotToken,
    chat_id: telegram.ChatId,
  )
}

pub fn update(model: Model, event) {
  case event {
    event.Key(key.Char("q")) | event.Key(key.Esc) -> #(model, command.quit())
    event.Key(key.Char("k")) | event.Key(key.Up) -> {
      #(
        Model(..model, media: media.move_selected_up(model.media)),
        command.none(),
      )
    }
    event.Key(key.Char("j")) | event.Key(key.Down) -> {
      #(
        Model(..model, media: media.move_selected_down(model.media)),
        command.none(),
      )
    }
    event.Key(key.Char("K")) -> {
      #(
        Model(..model, media: media.move_selected_media_up(model.media)),
        command.none(),
      )
    }
    event.Key(key.Char("J")) -> {
      #(
        Model(..model, media: media.move_selected_media_down(model.media)),
        command.none(),
      )
    }

    event.Key(key.Char("i")) -> {
      telegram.get_chat(model.logger, model.bot_token, model.chat_id)

      #(model, command.none())
    }

    event.Key(key.Char("u")) -> {
      #(
        model,
        command.from(fn(_) {
          telegram.send_media_group(
            model.logger,
            model.bot_token,
            model.chat_id,
            model.media,
          )
          Nil
        }),
      )
    }

    _otherwise -> #(model, command.none())
  }
}

pub fn view(model: Model) {
  let header = "Telegram Lacky - Create Gallery"
  let footer = "Press q to quit."

  let media =
    model.media
    |> list.map(fn(m) {
      case m.selected {
        True -> " [x] " <> m.caption
        False -> " [ ] " <> m.caption
      }
    })
    |> string.join("\n")

  [header, media, footer] |> string.join("\n\n")
}
