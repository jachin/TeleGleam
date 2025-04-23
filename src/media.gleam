import filepath
import gleam/int
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
  Media(
    media_type: MediaType,
    caption: String,
    file_path: String,
    order: Int,
    selected: Bool,
  )
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
          selected: i == 0,
        )
      })
    })
  })
  |> result.map(option.values)
  |> result.unwrap([])
}

pub fn get_selected_index(media: List(Media)) {
  media
  |> list.reduce(fn(acc, m) {
    case m.selected {
      True -> m
      False -> acc
    }
  })
  |> result.map(fn(r) { r.order })
  |> result.unwrap(0)
}

pub fn change_selected_index(media: List(Media), new_index: Int) {
  let old_selected_index = get_selected_index(media)
  media
  |> list.map(fn(m) {
    case m.order == old_selected_index {
      True -> Media(..m, selected: False)
      False -> m
    }
  })
  |> list.map(fn(m) {
    case m.order == new_index {
      True -> Media(..m, selected: True)
      False -> m
    }
  })
}

pub fn move_selected_up(media: List(Media)) {
  let old_selected_index = get_selected_index(media)
  let new_selected_index = case old_selected_index {
    0 -> list.length(media) - 1
    i -> i - 1
  }
  change_selected_index(media, new_selected_index)
}

pub fn move_selected_down(media: List(Media)) {
  let old_selected_index = get_selected_index(media)
  let max_index = list.length(media) - 1
  let new_selected_index = case old_selected_index == max_index {
    True -> 0
    False -> old_selected_index + 1
  }
  change_selected_index(media, new_selected_index)
}
