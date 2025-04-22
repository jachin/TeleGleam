import filepath
import gleam/list
import gleam/option
import gleam/result
import glexif
import simplifile

pub type MediaType {
  Photo
  Video
}

pub type Media {
  Media(media_type: MediaType, caption: String, file_path: String, order: Int)
}

fn file_path_to_media_type(path) {
  case filepath.extension(path) {
    Ok(extension) ->
      case extension {
        "jpg" -> option.Some(Photo)
        "jpeg" -> option.Some(Photo)
        "mp4" -> option.Some(Video)
        _ -> option.None
      }
    Error(_) -> option.None
  }
}

fn is_media_file(path) {
  option.is_some(file_path_to_media_type(path))
}

pub fn find_media(absolute_media_path) {
  result.map(absolute_media_path, fn(p) { simplifile.get_files(p) })
  |> result.flatten()
  |> result.map(fn(files) { list.filter(files, is_media_file) })
  |> result.map(fn(files) {
    list.map(files, fn(f) { echo simplifile.file_info(f) })
    list.index_map(files, fn(f, i) {
      file_path_to_media_type(f)
      |> option.map(fn(media_type) {
        Media(
          media_type: media_type,
          caption: option.unwrap(
            glexif.get_exif_data_for_file(f).image_description,
            "",
          ),
          file_path: f,
          order: i,
        )
      })
    })
  })
  |> result.map(option.values)
  |> result.unwrap([])
}
