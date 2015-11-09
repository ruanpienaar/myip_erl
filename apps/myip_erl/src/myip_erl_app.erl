-module(myip_erl_app).

-behaviour(application).

-include("../include/myip_erl.hrl").

-export([start/0, start/2, stop/1]).

%% ===================================================================

start() ->
    ?INFO("STARTING myip_erl ................... \n"),
    ok = application:start(asn1),
    ok = application:start(crypto),
    ok = application:start(public_key),
    ok = application:start(ssl),
    ok = application:start(compiler),
    ok = application:start(inets),
    ok = application:start(syntax_tools),
    ok = application:start(sasl),
    ok = application:start(goldrush),
    ok = application:start(lager).

start(_StartType, _StartArgs) ->
    myip_erl_sup:start_link().

stop(_State) ->
    ok.
