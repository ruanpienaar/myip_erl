#!/bin/bash
erl -pa deps/*/ebin apps/*/ebin -name myip_erl@$1 -setcookie myip_erl -config rel/myip_erl/releases/1/sys.config -s myip_erl_app start -detached -noinput -heart -smp
