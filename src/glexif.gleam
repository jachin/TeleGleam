import file_streams/file_stream
import glexif/exif_tag
import glexif/internal/raw

pub fn get_exif_data_for_file(file_path) -> exif_tag.ExifTagRecord {
  let assert Ok(rs) = file_stream.open_read(file_path)
  // Move the stream up until you hit the exif marker
  let _ = raw.read_until_marker(rs)
  // Get the size of the exif segment
  let size = raw.read_exif_size(rs)
  // close up the stream as we don't need it anymore (for now at least)
  let _ = file_stream.close(rs)

  // re-open the file stream
  let assert Ok(rs) = file_stream.open_read(file_path)
  // TODO: this feels silly, should I not have closed the file steam?
  // I'm just reading the file again until I get to the right spot.
  let _ = raw.read_until_marker(rs)
  let _ = raw.read_exif_size(rs)

  // read in the exif segment and then parse out the final results
  // I am not sure at this point if there are multiple exif segments to a file
  // so this may need to be updated to advance the read stream to the next segment
  case raw.read_exif_segment(rs, size) {
    Ok(segment) -> {
      // Close the file stream (again)
      let _ = file_stream.close(rs)
      raw.parse_exif_data_as_record(segment)
    }
    _ -> panic
  }
}
