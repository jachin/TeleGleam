import gleeunit
import gleeunit/should
import media.{Media}

pub fn main() {
  gleeunit.main()
}

fn test_data() {
  [
    Media(
      media_type: media.Photo(media.Jepg),
      caption: "red",
      file_path: "red.jpg",
      order: 0,
      selected: False,
    ),
    Media(
      media_type: media.Photo(media.Jepg),
      caption: "blue",
      file_path: "blue.jpg",
      order: 1,
      selected: True,
    ),
    Media(
      media_type: media.Photo(media.Jepg),
      caption: "gree",
      file_path: "green.jpg",
      order: 2,
      selected: False,
    ),
  ]
}

pub fn get_selected_index_test() {
  media.get_selected_index(test_data()) |> should.equal(1)
}

pub fn get_selected_order_test() {
  media.get_selected_order(test_data()) |> should.equal(1)
}

pub fn move_selected_up_test() {
  media.move_selected_up(test_data())
  |> media.get_selected_index
  |> should.equal(0)
}

pub fn move_selected_down_test() {
  media.move_selected_down(test_data())
  |> media.get_selected_index
  |> should.equal(2)
}

pub fn sort_media_test() {
  let disordered_data = [
    Media(
      media_type: media.Photo(media.Jepg),
      caption: "gree",
      file_path: "green.jpg",
      order: 2,
      selected: False,
    ),
    Media(
      media_type: media.Photo(media.Jepg),
      caption: "blue",
      file_path: "blue.jpg",
      order: 1,
      selected: True,
    ),
    Media(
      media_type: media.Photo(media.Jepg),
      caption: "red",
      file_path: "red.jpg",
      order: 0,
      selected: False,
    ),
  ]
  media.sort_media(disordered_data)
  |> should.equal(test_data())
}

pub fn move_selected_media_up_test() {
  test_data()
  |> media.move_selected_media_up()
  |> echo
  |> media.get_selected_index
  |> should.equal(0)
}
