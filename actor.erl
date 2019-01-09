-module(actor).
-compile(export_all).

% TODO: Feldgroesse anpassen
% TODO: Kommentieren, Cleanup
% TODO: ggf Feldgroesse und Schiffsanzahl frei waehlbar

%Feldgroesse : 4 x 4
%Schiffe: 3

% connect: Spiel starten; Ablauf: 
% 1. Spieler 1 stellt Verbindung zu Spieler 2 herstellen
% 2. Spieler 2 erwartet mit host() Spielfeld von Spieler 1
% 3. Spieler 1 besetzt das eigene Spielfeld und wartet auf Spieler 2
connect() ->
    io:format("Enter opponent name: (name@hostname)~n"),
    Input = io:fread('enter>',"~a"),
    Opponent = lists:nth(1, element(2,Input)),
    io:format("Opponent: ~s~n", [Opponent]),
    net_kernel:connect_node(Opponent), % Verbindung zur Gegner-Node herstellen
    register(shell,self()), % Shell registrieren
    Myfield = init(), % Eigenes Feld besetzen
    %rpc:async_call(Opponent,actor,registershell,[]),
    {shell, Opponent} ! {self(), {Myfield, {}}, {66, 3}}, % eigenes Feld an Gegner uebermitteln
    do_it(). % in receive routine springen

% shell registrieren & in receive routine springen (fuer Spieler 2, rpc:async_call kein Effekt??)
host() ->
    register(shell,self()),
    do_it().

% Spielroutine
do_it() ->
    receive
            {_, {_, _}, {0, _}} -> % defeat: Zahl der eignene Schiffe = 0
                io:format("~nLoser!"),
                exit(normal);

            {From, {Hisfield, {}}, {_, 3}} -> % init actor 2: Eigenes Feld leer
                io:format("~nFrom: ~p~n", [From]),
                Myfield = init(), % eigenes Feld besetzen
                From ! {self(), {Myfield, Hisfield}, {3, 3}}; % Antwort an Gegenspieler
                
            {From, {Hisfield, Myfield}, {Myships, Hisships}} -> % Schussroutine
                io:format("~n~n~n"),
                io:format("Opponent field:~n"),
                print_field(Hisfield, true), % Gegnerfeld anzeigen
                io:format("Your field:~n"),
                print_field(Myfield, false), % Eigenes Feld anzeigen
                Shotresult = shoot(Hisfield, Hisships), % Schuss abegeben
                Hisfieldnew = element(1, Shotresult), % Gegnerisches Feld updaten
                Hisshipsnew = element(2, Shotresult), % Gegnerische Schiffsanzahl updaten
                                                
                print_field(Hisfieldnew, true), % Neues gegnerisches Feld anzeigen
                From ! {self(), {Myfield, Hisfieldnew}, {Hisshipsnew, Myships}}, % Antwort an Gegenspieler
                if 
                    Hisshipsnew == 0 -> % Wenn Gegenspieler keine Schiffe mehr hat -> Victory, Spiel auf node beenden
                        io:format("Victory!~n"),
                        exit(normal);
                    Hisshipsnew > 0 -> 
                        io:format("")
                end
    end,
    do_it(). % Rekursion

% Eigenes Feld besetzen
init() ->
    Field = init_field(), % Leeres Feld erzeugen
    Fieldnew = place_ships(Field, 3), % Schiffe platzieren
    print_field(Fieldnew, false), % Feld ausgeben
    Fieldnew. % Feld zurueckgeben
    
% Schuss setzen
shoot(Field, Ships) ->
    io:format("Take a shot: [s]hoot <row> <column>~n"),
    io:format("Example: s 2 4 to shoot at field on row 2, column 4~n"),
    Input = io:fread('enter>', "~s~d~d"), % Koordinaten einlesen
    Row = lists:nth(2, element(2,Input)), % Zeilenindex auslesen
    Column = lists:nth(3, element(2,Input)), % Spaltenindex auslesen
    if
        (Row < 1) or (Row > 4) -> % Koordinaten auf Korrektheit pruefen...
            io:format("Error: Field does not exist, try again!~n"),
            shoot(Field, Ships);
        (Column < 1) or (Column > 4) ->
            io:format("Error: Field does not exist, try again!~n"),
            shoot(Field, Ships);
        true -> 
            Ro = element(Row, Field), % Zeilentupel auslesen
            Char = element(Column, Ro), % Kaestchen auslesen
            if
                Char == '*' -> % * ^= Schiff => Treffer
                    Fieldnew = update_field(Field, Row, Column, 'x'), % Kaestchen updaten
                    io:format("Hit!~n"),
                    {Fieldnew, Ships - 1}; % Neues Feld und Schiffsanzahl - 1 zurueckgeben
                true -> % sonst kein Treffer...
                    Fieldnew = update_field(Field, Row, Column, 'o'), % Kaestchen updaten
                    io:format("Miss!~n"),
                    {Fieldnew, Ships} % Neues Feld zurueckgeben
            end
    end.
            
    
% Schiffe platzieren
place_ships(Field, Ships) ->
    if
        Ships == 0 -> Field; % Alle Schiffe platziert...
        Ships > 0 ->
            print_field(Field, false), % Feld ausgeben
            io:format("Ships to place: ~B | Place ship: [p]lace <row> <column>~n", [Ships]),
            io:format("Example: p 2 4 to place a ship on column 4 in row 2.~n"),
            Input = io:fread('enter>', "~s~d~d"), % Koordinaten einlesen
            Row = lists:nth(2, element(2,Input)), % Zeilenindex auslesen
            Column = lists:nth(3, element(2,Input)), % Spaltenindex auslesen
            if
            (Row < 1) or (Row > 4) -> % Koordinaten auf Korrektheit pruefen...
                io:format("Error: Field does not exist, try again!~n"),
                place_ships(Field, Ships);
            (Column < 1) or (Column > 4) ->
                io:format("Error: Field does not exist, try again!~n"),
                place_ships(Field, Ships);
            true -> 
                Fieldnew = update_field(Field, Row, Column, '*'), % Schiff setzen
                if 
                    not Fieldnew -> % Pruefen, dass kein Kaestchen doppelt besetzt...
                        io:format("Error: Field already taken, try again!~n"),
                        place_ships(Field, Ships);
                    true -> 
                        place_ships(Fieldnew, Ships - 1)
                end
            end
    end.

% Leeres Feld erzeugen
init_field() ->
    A = {" ", " ", " ", " "},
    B = {" ", " ", " ", " "},
    C = {" ", " ", " ", " "},
    D = {" ", " ", " ", " "},
    R = {A,B,C,D},
    R.
    

% Feld ausgeben
print_field(Field, Enemy) ->
    if 
        Enemy -> % Gegnerisches Feld -> Schiffspositionen maskieren...
            
            
            A = tuple_to_list(element(1, Field)),
            B = tuple_to_list(element(2, Field)),
            C = tuple_to_list(element(3, Field)),
            D = tuple_to_list(element(4, Field)),
            
            Anew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,A),
            Bnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,B),
            Cnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,C),
            Dnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,D),
            
            io:format("(~s)(~s)(~s)(~s)~n", [lists:nth(1,Anew),lists:nth(2,Anew),lists:nth(3,Anew),lists:nth(4,Anew)]),
            io:format("(~s)(~s)(~s)(~s)~n", [lists:nth(1,Bnew),lists:nth(2,Bnew),lists:nth(3,Bnew),lists:nth(4,Bnew)]),
            io:format("(~s)(~s)(~s)(~s)~n", [lists:nth(1,Cnew),lists:nth(2,Cnew),lists:nth(3,Cnew),lists:nth(4,Cnew)]),
            io:format("(~s)(~s)(~s)(~s)~n", [lists:nth(1,Dnew),lists:nth(2,Dnew),lists:nth(3,Dnew),lists:nth(4,Dnew)]);
            
            
        not Enemy ->
            A = element(1, Field),
            B = element(2, Field),
            C = element(3, Field),
            D = element(4, Field),
            io:format("(~s)(~s)(~s)(~s)~n", [element(1,A), element(2,A), element(3,A), element(4,A)]),
            io:format("(~s)(~s)(~s)(~s)~n", [element(1,B), element(2,B), element(3,B), element(4,B)]),
            io:format("(~s)(~s)(~s)(~s)~n", [element(1,C), element(2,C), element(3,C), element(4,C)]),
            io:format("(~s)(~s)(~s)(~s)~n", [element(1,D), element(2,D), element(3,D), element(4,D)])
    end.

% Feld updaten
update_field(Field, Row, Column, Char) ->
    C = element(Row, Field),
    if
        (Char == '*') and (element(Column, C) == '*') -> 
            false;
        true -> 
            Cnew = setelement(Column, C, Char),
            Fieldnew = setelement(Row, Field, Cnew),
            Fieldnew
    end.
    
    
