import filepath
import flash
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/javascript/promise
import gleam/json
import gleeunit/should
import media
import multipart_form
import multipart_form/field
import simplifile

pub fn send_message(logger, bot_token: String, chat_id: String, message: String) {
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
    base_req
    |> request.set_method(http.Post)
    |> request.set_header("Content-Type", "application/json")
    |> request.set_body(json_body)

  flash.info(logger, "Request is setup")

  send_request(req, logger)
}

pub fn send_media_group(
  logger,
  bot_token: String,
  chat_id: String,
  media_group: List(media.Media),
) {
  let json_body =
    json.object([
      #("chat_id", json.string(chat_id)),
      #("media", json.array(media_group, media.to_input_media_json)),
    ])
    |> json.to_string

  let assert Ok(form_data) =
    media.build_form_data_for_uploading(chat_id, json_body, media_group)

  let r =
    request.new()
    |> request.set_host("api.telegram.org")
    |> request.set_path(bot_token <> "/sendMediaGroup")
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

  resp
  |> response.get_header("content-type")
  |> should.equal(Ok("application/json"))

  promise.resolve(Ok(resp))
}

pub fn send_photo(
  logger,
  bot_token: String,
  chat_id: String,
  photo: media.Media,
) {
  let assert Ok(photo_bits) = simplifile.read_bits(photo.file_path)

  let form = [
    #("chat_id", field.String(chat_id)),
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
    |> request.set_path(bot_token <> "/sendPhoto")
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
