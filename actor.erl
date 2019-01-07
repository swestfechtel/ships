-module(actor).
-compile(export_all).

% TODO: Netzwerkkommunikation
% TODO: Gegnerisches Feld maskieren
% TODO: Fehlererkennung, z.B. Feld nicht doppelt belegbar
% TODO: Feldgroesse anpassen
% TODO: Kommentieren, Cleanup

do_it() ->
    receive
            {_, {_, _}, {0, _}} -> % defeat
                io:format("~nLoser!"),
                exit(normal);
            {start} -> % init actor 1
                io:format("~nCurrent Actor: ~p~n", [self()]),
                Myfield = init(),
                Pid = spawn(actor, do_it, []),
                Pid ! {self(), {Myfield, {}}, {66, 3}};
            {From, {Hisfield, {}}, {_, 3}} -> % init actor 2
                io:format("~nCurrent Actor: ~p~n", [self()]),
                Myfield = init(),
                From ! {self(), {Myfield, Hisfield}, {3, 3}};
            {From, {Hisfield, Myfield}, {Myships, Hisships}} -> 
                io:format("~nCurrent Actor: ~p~n", [self()]),
                io:format("~n~n~n"),
                io:format("Opponent field:~n"),
                print_field(Hisfield),
                io:format("Your field:~n"),
                print_field(Myfield),
                Shotresult = shoot(Hisfield, Hisships),
                Hisfieldnew = element(1, Shotresult),
                Hisshipsnew = element(2, Shotresult),
                                                
                print_field(Hisfieldnew),
                From ! {self(), {Myfield, Hisfieldnew}, {Hisshipsnew, Myships}},
                if 
                    Hisshipsnew == 0 -> 
                        io:format("Victory!~n"),
                        exit(normal);
                    Hisshipsnew > 0 -> 
                        io:format("")
                end
    end,
    do_it().
            
init() ->
    Field = init_field(),
    Fieldnew = place_ships(Field, 3),
    print_field(Fieldnew),
    Fieldnew.
    
shoot(Field, Ships) ->
    io:format("Take a shot: [s]hoot <row> <column>~n"),
    io:format("Example: s 2 4 to shoot at field on row 2, column 4~n"),
    Input = io:fread('enter>', "~s~d~d"),
    Row = lists:nth(2, element(2,Input)),
    Column = lists:nth(3, element(2,Input)),
    Ro = element(Row, Field),
    Char = element(Column, Ro),
    if
        Char == '*' -> 
            Fieldnew = update_field(Field, Row, Column, 'x'),
            io:format("Hit!~n"),
            {Fieldnew, Ships - 1};
        Char == " " ->
            Fieldnew = update_field(Field, Row, Column, 'o'),
            io:format("Miss!~n"),
            {Fieldnew, Ships}
    end.
    
            
    
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
    if
        Char == '*' and element(Column, C) == '*' -> false;
        true -> 
            Cnew = setelement(Column, C, Char),
            Fieldnew = setelement(Row, Field, Cnew),
            Fieldnew
    end.
    
    
