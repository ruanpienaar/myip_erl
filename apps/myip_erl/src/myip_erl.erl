-module(myip_erl).
-export([start_link/0]).
-include("../include/myip_erl.hrl").
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([email_new_ip_change/1]).
-define(SERVER, ?MODULE).
-define(STATE,  myip_erl_state).
-define(SLEEP, (1000 * 60) * 5). %% 5 minutes
-record(?STATE, { timer_ref, ip :: inet:ip_address(), refresh_interval }).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, {}, []).

%% @private
init({}) ->
    %% Build a URL checker, and fallback services...
    process_flag(trap_exit,true),
    ?INFO("myip_erl.erl INIT \n"),
    {ok,InitialIp} = application:get_env(myip_erl,initial_ip),
    RI = case application:get_env(myip_erl,refresh_interval) of
        undefined ->
            ?SLEEP;
        {ok,V} ->
            V
    end,
    TREF = erlang:start_timer(RI, self(), {msg,tick_be}),
    {ok,#?STATE{timer_ref=TREF, ip=InitialIp, refresh_interval = RI}}.

%% @private
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

%% @private
handle_cast(_Msg, State) ->
    {noreply, State}.

%% @private
handle_info({timeout,_TREF,{msg,tick_be}}, #?STATE{ ip = OldIp, refresh_interval = RI } = State) ->
  TREF = erlang:start_timer(RI, self(), {msg,tick_be}),
  try
    IP = get_my_ip(),
    case IP=:=OldIp of
        true  -> ok;
        false -> email_new_ip_change(IP)
    end,
    ?INFO("ip address : ~p\n",[IP]),
    {noreply, State#?STATE{ timer_ref = TREF, ip = IP }}
  catch
    C:E ->
	?INFO("lookup or email failed : ~p, ~p\n",[C,E]),
	{noreply,State#?STATE{ timer_ref = TREF }}
  end;
handle_info({'EXIT',_,Reason},State) ->
    ?WARNING("Trapping EXIT\n~p\n~p\n...\n",[Reason,erlang:get_stacktrace()]),
    {noreply,State};
handle_info(Error,State) ->
    ?WARNING("Unknown Error: ~p\n",[Error]),
    {noreply,State}.

%% @private
terminate(_Reason, _State) ->
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

get_my_ip() ->
    URL = "http://www.trackip.net/ip?json",
    {ok,{{"HTTP/1.1",200,"OK"},_Headers,JSON}} = httpc:request(URL),
    {A} = jiffy:decode(JSON),
    BinIP = proplists:get_value(<<"ip">>, A),
    {ok,IP} = inet:parse_ipv4_address(binary_to_list(BinIP)),
    IP.

email_new_ip_change(IP) ->
    try
        {ok,FD} = application:get_env(myip_erl,from_domain),
        {ok,TA} = application:get_env(myip_erl,to_address),
        {ok,UN} = application:get_env(myip_erl,un),
        {ok,PD} = application:get_env(myip_erl,passwd),
        {ok,R} = application:get_env(myip_erl,relay),
        MSG="Subject: testing\r\nFrom: Raspberry Pi Home \r\nTo: Ruan Pienaar \r\n\r\nYour new IP is :"++inet:ntoa(IP)++". ",

%% gen_smtp_client:send({"ruan804@gmail.com",["ruan800@gmail.com"],"\nTest\n"},[{relay,"smtp.gmail.com"},{username,"ruan804@gmail.com"},{password,""}])

        gen_smtp_client:send({FD,[TA],MSG},[{relay,R},{username,UN},{password,PD}])
    catch
        C:E ->
            ?WARNING("EMAIL FAILED : ~p\n~p\n~p\n}",[C,E,erlang:get_stacktrace()])
    end.
