import filepath
import flash
import gleam/dynamic
import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/javascript/promise
import gleam/json
import gleam/list
import gleam/result
import gleeunit/should
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

pub fn get_chat(
  logger,
  bot_token: BotToken,
  chat_id: ChatId,
) -> promise.Promise(Result(response.Response(ChatFullInfo), fetch.FetchError)) {
  flash.info(logger, "get_chat")

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

  let foo1 = fetch.send(req)
  let foo2: promise.Promise(
    Result(response.Response(dynamic.Dynamic), fetch.FetchError),
  ) = promise.try_await(foo1, fn(foo3) { fetch.read_json_body(foo3) })

  promise.tap(foo2, fn(result) { echo result })

  let foo4 =
    promise.await(
      foo2,
      fn(
        resp_result: Result(
          response.Response(dynamic.Dynamic),
          fetch.FetchError,
        ),
      ) {
        promise.resolve(parse_chat_response(resp_result))
      },
    )

  promise.tap(foo4, fn(result) { echo result })
}

fn parse_chat_response(
  resp_result: Result(response.Response(dynamic.Dynamic), fetch.FetchError),
) -> Result(response.Response(ChatFullInfo), fetch.FetchError) {
  case resp_result {
    Ok(resp) -> {
      let a =
        response.try_map(resp, fn(json_body) {
          decode.run(json_body, chat_full_info_decoder())
        })

      do_the_thing(a)
    }
    Error(error) -> Error(error)
  }
}

fn do_the_thing(
  a: Result(response.Response(ChatFullInfo), List(decode.DecodeError)),
) -> Result(response.Response(ChatFullInfo), fetch.FetchError) {
  case a {
    Ok(resp) -> {
      Ok(resp)
    }
    Error(err) -> {
      echo err
      Error(fetch.InvalidJsonBody)
    }
  }
}

// {
//   let bar3 = case resp_result {
//     Ok(resp) ->
//       let bar4 = response.try_map(resp, fn(json_body) {
//         decode.run(json_body, chat_full_info_decoder())
//       })
//       let bar5 = case bar4 {
//         Ok(chat_full_info) -> Ok(chat_full_info)
//         Err(error) -> Err(error)
//       }
//       bar5
//     error -> error
//   }
//   promise.resolve(bar3)
// }

pub fn send_message(
  logger,
  bot_token: BotToken,
  chat_id: ChatId,
  message: String,
) {
  flash.info(logger, "telegram_send_message")

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

  flash.info(logger, "json_body " <> json_body)

  let req =
    base_req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(json_body)

  flash.info(logger, "Request is setup")

  send_request(req, logger)
}

pub fn send_media_group(
  logger,
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

  use resp <- promise.try_await(fetch.send_bits(r))
  use resp_body <- promise.try_await(fetch.read_text_body(resp))

  flash.info(logger, "Request has been sent")

  // Detailed error logging
  flash.info(logger, "Response status: " <> resp.status |> int.to_string)
  flash.info(logger, "Response body: " <> resp_body.body)

  // We get a response record back
  resp.status
  |> should.equal(200)

  promise.resolve(Ok(resp))
}

pub fn send_photo(
  logger,
  bot_token: BotToken,
  chat_id: ChatId,
  photo: media.Media,
) {
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

  use resp <- promise.try_await(fetch.send_bits(photo_upload_request))
  use resp_body <- promise.try_await(fetch.read_text_body(resp))

  flash.info(logger, "Request has been sent")

  // Detailed error logging
  flash.info(logger, "Response status: " <> resp.status |> int.to_string)
  flash.info(logger, "Response body: " <> resp_body.body)

  // We get a response record back
  resp.status
  |> should.equal(200)

  resp
  |> response.get_header("content-type")
  |> should.equal(Ok("application/json"))

  promise.resolve(Ok(resp))
}

fn send_request(req, logger) {
  // Send the HTTP request to the server
  use resp <- promise.try_await(fetch.send(req))
  use resp_body <- promise.try_await(fetch.read_text_body(resp))

  flash.info(logger, "Request has been sent")

  // Detailed error logging
  flash.info(logger, "Response status: " <> resp.status |> int.to_string)
  flash.info(logger, "Response body: " <> resp_body.body)

  // We get a response record back
  resp.status
  |> should.equal(200)

  resp
  |> response.get_header("content-type")
  |> should.equal(Ok("application/json"))

  promise.resolve(Ok(resp))
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
