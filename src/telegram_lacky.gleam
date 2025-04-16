import argv
import dot_env
import dot_env/env
import filepath
import flash
import gleam/hackney
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleeunit/should
import glexif
import glint
import simplifile

type MediaType {
  Photo
  Video
}

type Media {
  Media(media_type: MediaType, caption: String, file_path: String, order: Int)
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

fn is_media_file(path) {
  case filepath.extension(path) {
    Ok(extension) ->
      case extension {
        "jpg" -> True
        "jpeg" -> True
        _ -> False
      }
    Error(_) -> False
  }
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

  let _ =
    result.map(absolute_media_path, fn(p) { simplifile.get_files(p) })
    |> result.flatten()
    |> result.map(fn(files) { list.filter(files, is_media_file) })
    |> result.map(fn(files) {
      list.map(files, fn(f) { io.println("file " <> f) })
      list.map(files, fn(f) { echo simplifile.file_info(f) })
      list.map(files, fn(f) {
        Media(
          media_type: Photo,
          caption: option.unwrap(
            glexif.get_exif_data_for_file(f).image_description,
            "",
          ),
          file_path: f,
          order: 0,
        )
      })
    })
  Nil
}

fn telegram_send_message(
  logger,
  bot_token: String,
  chat_id: String,
  message: String,
) {
  flash.info(logger, "telegram_send_message")

  let url = "https://api.telegram.org/" <> bot_token <> "/sendMessage"

  let assert Ok(base_req) = request.to(url)

  let json_body =
    json.object([
      #("chat_id", json.string(chat_id)),
      #("text", json.string(message)),
    ])
    |> json.to_string

  flash.info(logger, "json_body " <> json_body)

  let req =
    request.set_header(base_req, "Content-Type", "application/json")
    |> request.set_body(json_body)

  flash.info(logger, "Request is setup")

  // Send the HTTP request to the server
  use resp <- result.try(hackney.send(req))

  flash.info(logger, "Request has been sent")

  // Detailed error logging
  flash.info(logger, "Response status: " <> resp.status |> int.to_string)
  flash.info(logger, "Response body: " <> resp.body)

  // We get a response record back
  resp.status
  |> should.equal(200)

  resp
  |> response.get_header("content-type")
  |> should.equal(Ok("application/json"))

  Ok(resp)
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

  let _ = telegram_send_message(logger, bot_token, chat_id, message)

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
