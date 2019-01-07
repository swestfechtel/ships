-module(ships).
-export([main/0]).

main() -> 
    io:write("Starting..."),
    Pid = spawn(actor, do_it, []),
    Pid ! {start}.
    
