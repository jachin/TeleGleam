import filepath
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import glexif
import simplifile

pub type MediaType {
  Photo(PhotoFormat)
  Video
}

pub type PhotoFormat {
  Jepg
  Png
  Gif
  Webp
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
        "jpg" -> option.Some(Photo(Jepg))
        "jpeg" -> option.Some(Photo(Jepg))
        "png" -> option.Some(Photo(Png))
        "gif" -> option.Some(Photo(Gif))
        "mp4" -> option.Some(Video)
        _ -> option.None
      }
    Error(_) -> option.None
  }
}

fn is_media_file(path) {
  option.is_some(file_path_to_media_type(path))
}

pub fn media_to_mine_type(media_type: MediaType) {
  case media_type {
    Photo(format) ->
      case format {
        Jepg -> "image/jpeg"
        Png -> "image/png"
        Gif -> "image/gif"
        Webp -> "image/webp"
      }
    Video -> "video/mp4"
  }
}

pub fn media_type_to_telegram_media_type(media_type: MediaType) {
  case media_type {
    Photo(format) ->
      case format {
        Jepg -> "photo"
        Png -> "photo"
        Gif -> "photo"
        Webp -> "photo"
      }
    Video -> "video"
  }
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

pub fn file_path_to_media(path) {
  file_path_to_media_type(path)
  |> option.map(fn(media_type) {
    Media(
      media_type: media_type,
      caption: option.unwrap(
        glexif.get_exif_data_for_file(path).image_description,
        "",
      ),
      file_path: path,
      order: 0,
      selected: True,
    )
  })
}

pub fn get_selected(media: List(Media)) {
  media
  |> list.reduce(fn(acc, m) {
    case m.selected {
      True -> m
      False -> acc
    }
  })
}

pub fn get_selected_order(media: List(Media)) {
  media
  |> get_selected
  |> result.map(fn(r) { r.order })
  |> result.unwrap(0)
}

pub fn get_selected_index(media: List(Media)) {
  media
  |> list.index_fold(-1, fn(acc, m, i) {
    case acc >= 1 {
      True -> acc
      False ->
        case m.selected {
          True -> i
          False -> acc
        }
    }
  })
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

pub fn move_selected_media_up(media: List(Media)) {
  let current_selected_order = get_selected_order(media)
  let item_or_to_swap_with = current_selected_order - 1
  case current_selected_order {
    0 -> media
    _ ->
      media
      |> list.map(fn(m) {
        case
          m.order == current_selected_order,
          m.order == item_or_to_swap_with
        {
          True, False -> Media(..m, order: item_or_to_swap_with)
          False, True -> Media(..m, order: current_selected_order)
          _, _ -> m
        }
      })
      |> sort_media
  }
}

pub fn move_selected_media_down(media: List(Media)) {
  let current_selected_order = get_selected_order(media)
  let item_or_to_swap_with = current_selected_order + 1
  let max_index = list.length(media) - 1
  case current_selected_order == max_index {
    True -> media
    False ->
      media
      |> list.map(fn(m) {
        case
          m.order == current_selected_order,
          m.order == item_or_to_swap_with
        {
          True, False -> Media(..m, order: item_or_to_swap_with)
          False, True -> Media(..m, order: current_selected_order)
          _, _ -> m
        }
      })
      |> sort_media
  }
}

pub fn sort_media(media: List(Media)) {
  media |> list.sort(fn(a: Media, b: Media) { int.compare(a.order, b.order) })
}

pub fn to_input_media_json(media: Media) {
  json.object([
    #("type", case media.media_type {
      Photo(_) -> json.string("photo")
      Video -> json.string("video")
    }),
    #("caption", json.string(media.caption)),
    #("media", json.string("attach://" <> filepath.base_name(media.file_path))),
  ])
}
