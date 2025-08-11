import argv
import create_gallery
import dot_env
import dot_env/env
import filepath
import gleam/option
import gleam/result
import glight
import glint
import glint/constraint
import logging
import media
import simplifile
import telegram
import utils/logging as utils_logging

fn logger_level_flag() -> glint.Flag(String) {
  glint.string_flag("logger-level")
  |> glint.flag_help("The logger level")
  |> glint.flag_constraint(
    constraint.one_of(utils_logging.log_levels_as_strings()),
  )
  |> fn(flag) {
    case env.get_string("LOGGER_LEVEL") {
      Ok(value) -> flag |> glint.flag_default(value)
      Error(_) ->
        flag
        |> glint.flag_default(utils_logging.log_level_to_string(glight.Error))
    }
  }
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

fn telegram_chat_id_flag() -> glint.Flag(Int) {
  let flag =
    glint.int_flag("telegram-chat-id")
    |> glint.flag_help("The Telegram Chat ID")

  case env.get_int("TELEGRAM_CHAT_ID") {
    Ok(value) -> flag |> glint.flag_default(value)
    Error(_) -> flag
  }
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

fn create_telegram_gallery() -> glint.Command(Nil) {
  use <- glint.command_help("Uploads a set of media to telegram")
  use bot_token_flag <- glint.flag(telegram_bot_token_flag())
  use chat_id_flag <- glint.flag(telegram_chat_id_flag())
  use logger_level_flag <- glint.flag(logger_level_flag())
  use _, args, flags <- glint.command()
  let assert Ok(bot_token_string) = bot_token_flag(flags)
  let assert Ok(chat_id_string) = chat_id_flag(flags)
  let assert Ok(logger_level) =
    logger_level_flag(flags)
    |> result.map_error(fn(_) { "" })
    |> result.try(utils_logging.parse_string_to_log_level)

  let bot_token = telegram.BotToken(bot_token_string)
  let chat_id = telegram.ChatId(chat_id_string)

  let media_path = case args {
    [] -> "."
    [p, ..] -> p
  }

  let absolute_media_path = get_absolute_path(media_path)

  let media = media.find_media(absolute_media_path)
  create_gallery.main(logger_level, bot_token, chat_id, media)
}

fn post_simple_text_message() -> glint.Command(Nil) {
  use <- glint.command_help("Post a simple text message to Telegram")
  use bot_token <- glint.flag(telegram_bot_token_flag())
  use chat_id <- glint.flag(telegram_chat_id_flag())
  //use logger_level_flag <- glint.flag(logger_level_flag())
  use _, args, flags <- glint.command()
  let assert Ok(bot_token_string) = bot_token(flags)
  let assert Ok(chat_id_string) = chat_id(flags)

  let bot_token = telegram.BotToken(bot_token_string)
  let chat_id = telegram.ChatId(chat_id_string)

  logging.log(logging.Info, "Posting a simple text message")
  telegram.log_bot_token(bot_token, logging.Info)

  let assert Ok(message) = case args {
    [] -> Error("No message")
    [m, ..] -> Ok(m)
  }

  let response_result = telegram.send_message(bot_token, chat_id, message)

  let _ = case response_result {
    Ok(_) -> {
      Nil
    }
    Error(e) -> {
      case e {
        telegram.TelegramResponseError(_) -> {
          logging.log(logging.Error, "TelegramResponseError")
        }
        telegram.TelegramRequestError(_) -> {
          logging.log(logging.Error, "TelegramRequestError")
        }
        telegram.TelegramInvalidUriError -> {
          logging.log(logging.Error, "TelegramInvalidUriError")
        }
      }
    }
  }

  Nil
}

fn upload_photo() -> glint.Command(Nil) {
  use <- glint.command_help("Upload a photo to Telegram")
  use bot_token <- glint.flag(telegram_bot_token_flag())
  use chat_id <- glint.flag(telegram_chat_id_flag())
  // use logger_level_flag <- glint.flag(logger_level_flag())
  use _, args, flags <- glint.command()
  let assert Ok(bot_token_string) = bot_token(flags)
  let assert Ok(chat_id_string) = chat_id(flags)
  // let assert Ok(logger_level_string) = logger_level_flag(flags)

  let bot_token = telegram.BotToken(bot_token_string)
  let chat_id = telegram.ChatId(chat_id_string)
  // let logger = setup_logger_from_string(logger_level_string)

  logging.log(logging.Info, "Uploading a photo")

  let assert Ok(photo_path) = case args {
    [] -> Error("No photo path")
    [p, ..] -> Ok(p)
  }

  let assert Ok(absolute_photo_path) = get_absolute_path(photo_path)

  let assert option.Some(photo) = media.file_path_to_media(absolute_photo_path)

  let _ = telegram.send_photo(bot_token, chat_id, photo)

  Nil
}

pub fn main() {
  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(True)
  |> dot_env.load

  glight.configure([glight.File("log.txt")])
  glight.set_log_level(glight.Debug)

  //ffi.enable_file_logger("log.txt")

  glint.new()
  |> glint.with_name("telegleam")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: ["create-telegram-gallery"], do: create_telegram_gallery())
  |> glint.add(at: ["post-simple-text-message"], do: post_simple_text_message())
  |> glint.add(at: ["upload-photo"], do: upload_photo())
  |> glint.run(argv.load().arguments)
}
