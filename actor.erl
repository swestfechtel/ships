-module(actor).
-compile(export_all).

dew_it() ->
    receive
        {From, start} ->
            Field = init(),
            
return_pid ->
    receive
        {From} -> From ! self()
    end.

init() ->
    Field = init_field(),
    Fieldnew = place_ships(Field, 3),
    print_field(Fieldnew),
    Fieldnew.
    
place_ships(Field, Ships) ->
    if
        Ships == 0 -> Field;
        Ships > 0 ->
            print_field(Field),
            io:format("Ships to place: ~B | Place ship: [p]lace <row> <column>~n", [Ships]),
            io:format("Example: p 2 4 to place a ship on column 4 in row 2.~n"),
            Input = io:fread('enter>', "~s~d~d"),
            Row = lists:nth(2, element(2,Input)),
            Column = lists:nth(3, element(2,Input)),
            Fieldnew = update_field(Field, Row, Column, '*'),
            place_ships(Fieldnew, Ships - 1)
    end.

init_field() ->
    A = {" ", " ", " ", " "},
    B = {" ", " ", " ", " "},
    C = {" ", " ", " ", " "},
    D = {" ", " ", " ", " "},
    R = {A,B,C,D},
    R.
    
print_field(Field) ->
    A = element(1, Field),
    B = element(2, Field),
    C = element(3, Field),
    D = element(4, Field),
    io:format("(~s)(~s)(~s)(~s)~n", [element(1,A), element(2,A), element(3,A), element(4,A)]),
    io:format("(~s)(~s)(~s)(~s)~n", [element(1,B), element(2,B), element(3,B), element(4,B)]),
    io:format("(~s)(~s)(~s)(~s)~n", [element(1,C), element(2,C), element(3,C), element(4,C)]),
    io:format("(~s)(~s)(~s)(~s)~n", [element(1,D), element(2,D), element(3,D), element(4,D)]).

update_field(Field, Row, Column, Char) ->
    C = element(Row, Field),
    Cnew = setelement(Column, C, Char),
    Fieldnew = setelement(Row, Field, Cnew),
    Fieldnew.
    
