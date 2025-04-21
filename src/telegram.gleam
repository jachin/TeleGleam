import flash
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/javascript/promise
import gleam/json
import gleeunit/should

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
