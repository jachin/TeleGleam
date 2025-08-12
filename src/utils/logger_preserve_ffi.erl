-module(logger_preserve_ffi).

-export([save_state/0, restore_state/1, with_preserved_state/1]).

save_state() ->
    % Save all handlers
    Handlers = logger:get_handler_ids(),
    HandlerConfigs =
        lists:map(fun(Id) ->
                     {ok, Config} = logger:get_handler_config(Id),
                     {Id, Config}
                  end,
                  Handlers),

    % Save primary config
    PrimaryConfig = logger:get_primary_config(),

    % Save the complete state
    #{handlers => HandlerConfigs, primary => PrimaryConfig}.

restore_state(State) ->
    try
        % First, remove all current handlers
        CurrentHandlers = logger:get_handler_ids(),
        lists:foreach(fun(Id) -> logger:remove_handler(Id) end, CurrentHandlers),

        % Restore saved handlers
        HandlerConfigs = maps:get(handlers, State, []),
        lists:foreach(fun({Id, Config}) ->
                         Module = maps:get(module, Config),
                         logger:add_handler(Id, Module, Config)
                      end,
                      HandlerConfigs),

        % Restore primary config
        case maps:get(primary, State, undefined) of
            undefined ->
                ok;
            PrimaryConfig ->
                logger:set_primary_config(PrimaryConfig)
        end,

        ok
    catch
        Class:Error:Stack ->
            io:format("Error restoring logger state: ~p:~p~n~p~n", [Class, Error, Stack]),
            error
    end.

% Helper function that saves state, runs function, then restores
with_preserved_state(Fun) ->
    State = save_state(),
    try
        Fun()
    after
        restore_state(State)
    end.
