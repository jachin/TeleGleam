import argv
import dot_env
import dot_env/env
import filepath
import flash
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import media
import simplifile
import teashop
import teashop/command
import teashop/event
import teashop/key
import telegram

pub type Model {
  Model(media: List(media.Media))
}

fn telegram_bot_token_flag() -> glint.Flag(String) {
  let flag =
    glint.string_flag("telegram-bot-token")
    |> glint.flag_help("The Telegram Bot token")

  case env.get_string("TELEGRAM_BOT_TOKEN") {
    Ok(value) -> flag |> glint.flag_default(value)
    Error(_) -> flag
  }
}

fn telegram_chat_id_flag() -> glint.Flag(String) {
  let flag =
    glint.string_flag("telegram-chat-id")
    |> glint.flag_help("The Telegram Chat ID")

  case env.get_string("TELEGRAM_CHAT_ID") {
    Ok(value) -> flag |> glint.flag_default(value)
    Error(_) -> flag
  }
}

fn channel_flag() -> glint.Flag(String) {
  glint.string_flag("channel")
  // what should the default channel me?
  |> glint.flag_default("ME")
  |> glint.flag_help("The channel to upload to")
}

fn get_absolute_path(path) {
  case filepath.is_absolute(path) {
    True -> Ok(path)
    False ->
      simplifile.current_directory()
      |> result.map(fn(cwd) { filepath.join(cwd, path) })
      |> fn(r_path) {
        case r_path {
          Ok(path) ->
            case filepath.expand(path) {
              Ok(expanded_path) -> Ok(expanded_path)
              Error(_) -> Error(simplifile.Enoent)
            }
          error -> error
        }
      }
  }
}

pub fn update(model: Model, event) {
  case event {
    event.Key(key.Char("q")) | event.Key(key.Esc) -> #(model, command.quit())
    event.Key(key.Char("k")) | event.Key(key.Up) -> {
      #(Model(media: media.move_selected_up(model.media)), command.none())
    }
    event.Key(key.Char("j")) | event.Key(key.Down) -> {
      #(Model(media: media.move_selected_down(model.media)), command.none())
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

fn create_telegram_gallery(logger) -> glint.Command(Nil) {
  use <- glint.command_help("Uploads a set of media to telegram")
  use channel <- glint.flag(channel_flag())
  use _, args, flags <- glint.command()
  let assert Ok(channel_name) = channel(flags)

  flash.info(logger, "Creating Telegram gallery: " <> channel_name)

  let media_path = case args {
    [] -> "."
    [p, ..] -> p
  }

  let absolute_media_path = get_absolute_path(media_path)

  case absolute_media_path {
    Ok(cwd) -> io.println("Directory " <> cwd)
    Error(_) -> io.println("Something went wrong")
  }

  let _ = media.find_media(absolute_media_path)

  let app =
    teashop.app(
      fn(_) {
        #(
          Model(media: media.find_media(absolute_media_path)),
          command.set_window_title("teashop"),
        )
      },
      update,
      view,
    )
  teashop.start(app, Nil)

  Nil
}

fn post_simple_text_message(logger) -> glint.Command(Nil) {
  flash.info(logger, "Posting a simple text message")

  use <- glint.command_help("Post a simple text message to Telegram")
  use bot_token <- glint.flag(telegram_bot_token_flag())
  use chat_id <- glint.flag(telegram_chat_id_flag())
  use _, args, flags <- glint.command()
  let assert Ok(bot_token) = bot_token(flags)
  let assert Ok(chat_id) = chat_id(flags)

  let assert Ok(message) = case args {
    [] -> Error("No message")
    [m, ..] -> Ok(m)
  }

  let _ = telegram.send_message(logger, bot_token, chat_id, message)

  Nil
}

pub fn main() {
  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(True)
  |> dot_env.load

  let logger = flash.new(flash.InfoLevel, flash.text_writer)

  logger |> flash.info("ENV Loaded")
  glint.new()
  |> glint.with_name("telegram-lacky")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(
    at: ["create-telegram-gallery"],
    do: create_telegram_gallery(logger),
  )
  |> glint.add(
    at: ["post-simple-text-message"],
    do: post_simple_text_message(logger),
  )
  |> glint.run(argv.load().arguments)
}
