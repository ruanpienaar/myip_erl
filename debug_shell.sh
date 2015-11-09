#!/bin/bash
erl -name debug@$1 -setcookie myip_erl -remsh myip_erl@rppi.home -smp
