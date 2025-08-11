import filepath
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleeunit/should
import glight
import logging
import media
import multipart_form
import multipart_form/field
import simplifile

pub type ChatId {
  ChatId(Int)
}

pub type BotToken {
  BotToken(String)
}

pub type ChatFullInfo {
  ChatFullInfo(
    id: ChatId,
    chat_type: String,
    title: String,
    description: String,
  )
}

pub type TelegramRequestError {
  TelegramRequestError(httpc.HttpError)
  TelegramResponseError(json.DecodeError)
  TelegramInvalidUriError
}

fn chat_id_decoder() {
  decode.int |> decode.map(ChatId)
}

fn chat_full_info_decoder() {
  use id <- decode.subfield(["result", "id"], chat_id_decoder())
  use chat_type <- decode.subfield(["result", "type"], decode.string)
  use title <- decode.subfield(["result", "title"], decode.string)

  use description <- decode.subfield(["result", "description"], decode.string)
  decode.success(ChatFullInfo(id, chat_type, title, description))
}

fn chat_id_to_string(chat_id: ChatId) -> String {
  case chat_id {
    ChatId(id) -> id |> int.to_string
  }
}

fn bot_token_to_string(bot_token: BotToken) {
  case bot_token {
    BotToken(token) -> token
  }
}

pub fn log_bot_token(bot_token: BotToken, level: logging.LogLevel) {
  logging.log(level, "bot_token: " <> bot_token_to_string(bot_token))
}

pub fn get_chat(
  bot_token: BotToken,
  chat_id: ChatId,
) -> Result(ChatFullInfo, TelegramRequestError) {
  logging.log(logging.Info, "get_chat")

  let json_body =
    json.object([#("chat_id", json.string(chat_id_to_string(chat_id)))])
    |> json.to_string

  let req =
    request.new()
    |> request.set_host("api.telegram.org")
    |> request.set_path(bot_token_to_string(bot_token) <> "/getChat")
    |> request.set_method(http.Get)
    |> request.set_scheme(http.Https)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_query([#("chat_id", chat_id_to_string(chat_id))])
    |> request.set_body(json_body)

  // Send the HTTP request to the server
  use resp <- result.try(
    result.map_error(httpc.send(req), fn(e) { TelegramRequestError(e) }),
  )
  use chat <- result.try(
    json.parse(resp.body, chat_full_info_decoder())
    |> result.map_error(fn(e) { TelegramResponseError(e) }),
  )

  Ok(chat)
}

pub fn send_message(bot_token: BotToken, chat_id: ChatId, message: String) {
  logging.log(logging.Info, "telegram_send_message")

  let url =
    "https://api.telegram.org/"
    <> bot_token_to_string(bot_token)
    <> "/sendMessage"

  let assert Ok(base_req) = request.to(url)

  let json_body =
    json.object([
      #("chat_id", json.string(chat_id_to_string(chat_id))),
      #("text", json.string(message)),
    ])
    |> json.to_string

  logging.log(logging.Info, "json_body " <> json_body)

  let req =
    base_req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(json_body)

  logging.log(logging.Info, "Request is setup")

  send_request(req)
}

pub fn send_media_group(
  bot_token: BotToken,
  chat_id: ChatId,
  media_group: List(media.Media),
) {
  let json_body =
    json.array(media_group, media.to_input_media_json)
    |> json.to_string

  let assert Ok(form_data) =
    build_form_data_for_uploading(chat_id, json_body, media_group)

  let r =
    request.new()
    |> request.set_host("api.telegram.org")
    |> request.set_path(bot_token_to_string(bot_token) <> "/sendMediaGroup")
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> multipart_form.to_request(form_data)

  use resp <- result.try(httpc.send_bits(r))

  glight.logger() |> glight.info("Request has been sent")

  // Detailed error logging
  logging.log(logging.Info, "Response status: " <> resp.status |> int.to_string)
  //logging.log(logging.Info, "Response body: " <> resp_body.body)

  // We get a response record back
  resp.status
  |> should.equal(200)

  Ok(resp)
}

pub fn send_photo(bot_token: BotToken, chat_id: ChatId, photo: media.Media) {
  glight.logger() |> glight.info("send_photo")
  let assert Ok(photo_bits) = simplifile.read_bits(photo.file_path)

  let form = [
    #("chat_id", field.String(chat_id_to_string(chat_id))),
    #(
      "photo",
      field.File(
        filepath.base_name(photo.file_path),
        media.media_to_mine_type(photo.media_type),
        photo_bits,
      ),
    ),
  ]

  let photo_upload_request =
    request.new()
    |> request.set_host("api.telegram.org")
    |> request.set_path(bot_token_to_string(bot_token) <> "/sendPhoto")
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> multipart_form.to_request(form)

  glight.logger() |> glight.info("send_photo request is ready")

  case
    httpc.dispatch_bits(
      httpc.configure() |> httpc.timeout(5000),
      photo_upload_request,
    )
  {
    Ok(response) -> {
      glight.logger() |> glight.info("Request has been sent")
      Ok(response)
    }
    Error(error) -> {
      glight.logger() |> glight.error("Request failed")

      case error {
        httpc.InvalidUtf8Response ->
          glight.logger() |> glight.error("InvalidUtf8Response")
        httpc.FailedToConnect(_, _) ->
          glight.logger() |> glight.error("FailedToConnect")
        httpc.ResponseTimeout ->
          glight.logger() |> glight.error("ResponseTimeout")
      }
      Error(TelegramRequestError(error))
    }
  }
}

fn send_request(req) {
  glight.logger() |> glight.info("Send a request")

  // Send the HTTP request to the server
  let resp_result =
    httpc.send(req) |> result.map_error(fn(e) { TelegramRequestError(e) })

  case resp_result {
    Ok(resp) -> {
      glight.logger() |> glight.info("Request has been sent")

      // Detailed error logging
      glight.logger()
      |> glight.info("Response status: " <> resp.status |> int.to_string)

      glight.logger() |> glight.info("Response body: " <> resp.body)

      // We get a response record back
      resp.status
      |> should.equal(200)

      resp
      |> response.get_header("content-type")
      |> should.equal(Ok("application/json"))
    }
    Error(_) -> {
      glight.logger() |> glight.error("Request has failed")
      Nil
    }
  }

  resp_result
}

pub fn build_form_data_for_uploading(
  chat_id: ChatId,
  json_body: String,
  media_group: List(media.Media),
) {
  let media_data =
    list.map(media_group, fn(m) {
      simplifile.read_bits(m.file_path)
      |> result.map(fn(media_bits) { #(m, media_bits) })
    })
  case result.all(media_data) {
    Ok(media_data) ->
      media_data
      |> list.fold(
        [
          #("chat_id", field.String(chat_id_to_string(chat_id))),
          #("media", field.String(json_body)),
        ],
        fn(media_form_data, data) {
          let #(media, bits) = data
          let file_name = filepath.base_name(media.file_path)
          let mine_type = media.media_to_mine_type(media.media_type)
          list.append(media_form_data, [
            #(file_name, field.File(file_name, mine_type, bits)),
          ])
        },
      )
      |> Ok
    Error(error) -> Error(error)
  }
}
