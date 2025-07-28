-module(erlib).

-export([enable_file_logger/1]).

enable_file_logger(file_path) ->
    logger:add_handler(my_standard_h,
                       logger_std_h,
                       #{config => #{file => file_path, filesync_repeat_interval => 1000}}).
