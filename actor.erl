-module(actor).
-compile(export_all).

% TODO: Feldgroesse anpassen
% TODO: ggf Feldgroesse und Schiffsanzahl frei waehlbar

% Feldgroesse : 10 x 10
% Schiffe: 10 Schiffe

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
    {shell, Opponent} ! {self(), {Myfield, {}}, {66, 10}}, % eigenes Feld an Gegner uebermitteln
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

            {From, {Hisfield, {}}, {_, 10}} -> % init actor 2: Eigenes Feld leer
                io:format("~nFrom: ~p~n", [From]),
                Myfield = init(), % eigenes Feld besetzen
                From ! {self(), {Myfield, Hisfield}, {10, 10}}; % Antwort an Gegenspieler
                
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
    Fieldnew = place_ships(Field, 10), % Schiffe platzieren
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
        (Row < 1) or (Row > 10) -> % Koordinaten auf Korrektheit pruefen...
            io:format("Error: Field does not exist, try again!~n"),
            shoot(Field, Ships);
        (Column < 1) or (Column > 10) ->
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
            (Row < 1) or (Row > 10) -> % Koordinaten auf Korrektheit pruefen...
                io:format("Error: Field does not exist, try again!~n"),
                place_ships(Field, Ships);
            (Column < 1) or (Column > 10) ->
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
    A = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    B = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    C = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    D = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    E = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    F = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    G = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    H = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    I = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    J = {" ", " ", " ", " ", " ", " ", " ", " ", " ", " "},
    R = {A,B,C,D,E,F,G,H,I,J},
    R.
    

% Feld ausgeben
print_field(Field, Enemy) ->
    if 
        Enemy -> % Gegnerisches Feld -> Schiffspositionen maskieren...
            
            
            A = tuple_to_list(element(1, Field)),
            B = tuple_to_list(element(2, Field)),
            C = tuple_to_list(element(3, Field)),
            D = tuple_to_list(element(4, Field)),
            E = tuple_to_list(element(5, Field)),
            F = tuple_to_list(element(6, Field)),
            G = tuple_to_list(element(7, Field)),
            H = tuple_to_list(element(8, Field)),
            I = tuple_to_list(element(9, Field)),
            J = tuple_to_list(element(10, Field)),
            
            Anew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,A),
            Bnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,B),
            Cnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,C),
            Dnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,D),
            Enew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,E),
            Fnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,F),
            Gnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,G),
            Hnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,H),
            Inew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,I),
            Jnew = lists:map(fun(X) -> if X == '*' -> " "; true -> X end end,J),
            
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Anew),lists:nth(2,Anew),lists:nth(3,Anew),lists:nth(4,Anew),lists:nth(5,Anew),lists:nth(6,Anew),lists:nth(7,Anew),lists:nth(8,Anew),lists:nth(9,Anew),lists:nth(10,Anew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Bnew),lists:nth(2,Bnew),lists:nth(3,Bnew),lists:nth(4,Bnew),lists:nth(5,Bnew),lists:nth(6,Bnew),lists:nth(7,Bnew),lists:nth(8,Bnew),lists:nth(9,Bnew),lists:nth(10,Bnew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Cnew),lists:nth(2,Cnew),lists:nth(3,Cnew),lists:nth(4,Cnew),lists:nth(5,Cnew),lists:nth(6,Cnew),lists:nth(7,Cnew),lists:nth(8,Cnew),lists:nth(9,Cnew),lists:nth(10,Cnew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Dnew),lists:nth(2,Dnew),lists:nth(3,Dnew),lists:nth(4,Dnew),lists:nth(5,Dnew),lists:nth(6,Dnew),lists:nth(7,Dnew),lists:nth(8,Dnew),lists:nth(9,Dnew),lists:nth(10,Dnew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Enew),lists:nth(2,Enew),lists:nth(3,Enew),lists:nth(4,Enew),lists:nth(5,Enew),lists:nth(6,Enew),lists:nth(7,Enew),lists:nth(8,Enew),lists:nth(9,Enew),lists:nth(10,Enew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Fnew),lists:nth(2,Fnew),lists:nth(3,Fnew),lists:nth(4,Fnew),lists:nth(5,Fnew),lists:nth(6,Fnew),lists:nth(7,Fnew),lists:nth(8,Fnew),lists:nth(9,Fnew),lists:nth(10,Fnew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Gnew),lists:nth(2,Gnew),lists:nth(3,Gnew),lists:nth(4,Gnew),lists:nth(5,Gnew),lists:nth(6,Gnew),lists:nth(7,Gnew),lists:nth(8,Gnew),lists:nth(9,Gnew),lists:nth(10,Gnew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Hnew),lists:nth(2,Hnew),lists:nth(3,Hnew),lists:nth(4,Hnew),lists:nth(5,Hnew),lists:nth(6,Hnew),lists:nth(7,Hnew),lists:nth(8,Hnew),lists:nth(9,Hnew),lists:nth(10,Hnew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Inew),lists:nth(2,Inew),lists:nth(3,Inew),lists:nth(4,Inew),lists:nth(5,Inew),lists:nth(6,Inew),lists:nth(7,Inew),lists:nth(8,Inew),lists:nth(9,Inew),lists:nth(10,Inew)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [lists:nth(1,Jnew),lists:nth(2,Jnew),lists:nth(3,Jnew),lists:nth(4,Jnew),lists:nth(5,Jnew),lists:nth(6,Jnew),lists:nth(7,Jnew),lists:nth(8,Jnew),lists:nth(9,Jnew),lists:nth(10,Jnew)]);
            
            
        not Enemy ->
            A = element(1, Field),
            B = element(2, Field),
            C = element(3, Field),
            D = element(4, Field),
            E = element(5, Field),
            F = element(6, Field),
            G = element(7, Field),
            H = element(8, Field),
            I = element(9, Field),
            J = element(10, Field),
            
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,A), element(2,A), element(3,A), element(4,A),element(5,A),element(6,A), element(7,A), element(8,A), element(9,A),element(10,A)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,B), element(2,B), element(3,B), element(4,B),element(5,B),element(6,B), element(7,B), element(8,B), element(9,B),element(10,B)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,C), element(2,C), element(3,C), element(4,C),element(5,C),element(6,C), element(7,C), element(8,C), element(9,C),element(10,C)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,D), element(2,D), element(3,D), element(4,D),element(5,D),element(6,D), element(7,D), element(8,D), element(9,D),element(10,D)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,E), element(2,E), element(3,E), element(4,E),element(5,E),element(6,E), element(7,E), element(8,E), element(9,E),element(10,E)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,F), element(2,F), element(3,F), element(4,F),element(5,F),element(6,F), element(7,F), element(8,F), element(9,F),element(10,F)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,G), element(2,G), element(3,G), element(4,G),element(5,G),element(6,G), element(7,G), element(8,G), element(9,G),element(10,G)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,H), element(2,H), element(3,H), element(4,H),element(5,H),element(6,H), element(7,H), element(8,H), element(9,H),element(10,H)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,I), element(2,I), element(3,I), element(4,I),element(5,I),element(6,I), element(7,I), element(8,I), element(9,I),element(10,I)]),
            io:format("(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)(~s)~n", [element(1,J), element(2,J), element(3,J), element(4,J),element(5,J),element(6,J), element(7,J), element(8,J), element(9,J),element(10,J)])
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
    
    
