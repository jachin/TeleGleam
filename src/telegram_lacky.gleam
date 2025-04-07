import argv
import filepath
import gleam/io
import gleam/list
import gleam/result
import glint
import simplifile

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

fn create_telegram_gallery() -> glint.Command(Nil) {
  use <- glint.command_help("Uploads a set of media to telegram")
  use channel <- glint.flag(channel_flag())
  use _, args, flags <- glint.command()
  let assert Ok(channel_name) = channel(flags)

  io.println("Creating Telegram gallery..." <> channel_name)

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
    })
  Nil
}

fn post_simple_text_message() -> glint.Command(Nil) {
  use <- glint.command_help("Post a simple text message to Telegram")
  use _, args, _ <- glint.command()

  let message = case args {
    [] -> Error("No message")
    [m, ..] -> Ok(m)
  }

  case message {
    Ok(m) -> echo "Let's print a message " <> m
    Error(e) -> echo e
  }
  Nil
}

pub fn main() {
  glint.new()
  |> glint.with_name("telegram-lacky")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: create_telegram_gallery())
  |> glint.add(at: ["create-telegram-gallery"], do: create_telegram_gallery())
  |> glint.add(at: ["post-simple-text-message"], do: post_simple_text_message())
  |> glint.run(argv.load().arguments)
}
