--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 75725848aa1459f81be595d1e49bfa35b780f527cdae2ce12f35dc94201bc63a
--
package Lovelace_Word_Rules_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;
   Max_Word : constant := 256;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);
   VT : constant Character := Character'Val (11);
   FF : constant Character := Character'Val (12);
   CR : constant Character := Character'Val (13);

   If_Kw    : constant String := "if";
   Elsif_Kw : constant String := "elsif";

   type Guard is record
      First : Positive := 1;
      Last  : Natural  := 0;
   end record;

   type Guard_Array is array (Positive range <>) of Guard;

   subtype Depth_Type is Integer range -Max_Text .. Max_Text;

   function Is_Word_Char (C : Character) return Boolean is
     (C = '_' or else C in '0' .. '9' or else C in 'A' .. 'Z' or else C in 'a' .. 'z');

   function Is_Collapse_Space (C : Character) return Boolean is
     (C = HT or else C = LF or else C = FF or else C = CR or else C = ' ');

   function Is_Trim_Space (C : Character) return Boolean is
     (C = HT or else C = LF or else C = VT or else C = FF or else C = CR or else C = ' ');

   function Lower (C : Character) return Character is
     (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C)
     with Post => (if C not in 'A' .. 'Z' then Lower'Result = C);

   function Equal_CI (A : String; B : String) return Boolean is
     (A'Length = B'Length
      and then (for all K in 0 .. A'Length - 1 => Lower (A (A'First + K)) = Lower (B (B'First + K))))
     with Pre => A'Length <= Max_Text and then B'Length <= Max_Text;

   function Is_Word_Form (W : String) return Boolean is
     (W'First = 1
      and then W'Length >= 1
      and then W'Length <= Max_Word
      and then (for all K in 1 .. W'Length => Is_Word_Char (W (K))));

   function Whole_Word_At (Text : String; P : Positive; Kw : String) return Boolean is
     (Kw'Length <= Text'Length
      and then P <= Text'Length - Kw'Length + 1
      and then Text (P .. P + Kw'Length - 1) = Kw
      and then (P = 1 or else not Is_Word_Char (Text (P - 1)))
      and then (P = Text'Length - Kw'Length + 1 or else not Is_Word_Char (Text (P + Kw'Length))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Is_Word_Form (Kw);

   function Keyword_At_Or_After (Text : String; Kw : String; From : Positive) return Natural is
     (if From > Text'Length then 0
      elsif Whole_Word_At (Text, From, Kw) then From
      else Keyword_At_Or_After (Text, Kw, From + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then From <= Text'Length + 1,
          Post => (Keyword_At_Or_After'Result = 0
                   or else (Keyword_At_Or_After'Result >= From and then Keyword_At_Or_After'Result <= Text'Length))
                   and then (if Keyword_At_Or_After'Result > 0 then Whole_Word_At (Text, Keyword_At_Or_After'Result, Kw)),
          Subprogram_Variant => (Decreases => Text'Length - From + 1);

   function Last_Keyword_Before (Text : String; Kw : String; Before : Positive) return Natural is
     (if Before = 1 then 0
      elsif Whole_Word_At (Text, Before - 1, Kw) then Before - 1
      else Last_Keyword_Before (Text, Kw, Before - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Before <= Text'Length + 1,
          Post => (Last_Keyword_Before'Result < Before)
                   and then (if Last_Keyword_Before'Result > 0 then Whole_Word_At (Text, Last_Keyword_Before'Result, Kw)),
          Subprogram_Variant => (Decreases => Before);

   function Name_Length (Name : String; With_Result : Boolean) return Positive is
     (Name'Length + (if With_Result then 7 else 0))
     with Pre  => Is_Word_Form (Name),
          Post => Name_Length'Result >= Name'Length and then Name_Length'Result <= Name'Length + 7;

   function Name_At (Text : String; P : Positive; Name : String; With_Result : Boolean) return Boolean is
     (Name_Length (Name, With_Result) <= Text'Length
      and then P <= Text'Length - Name_Length (Name, With_Result) + 1
      and then (P = 1 or else not Is_Word_Char (Text (P - 1)))
      and then Equal_CI (Text (P .. P + Name'Length - 1), Name)
      and then (if With_Result then Equal_CI (Text (P + Name'Length .. P + Name'Length + 6), "'result"))
      and then (P = Text'Length - Name_Length (Name, With_Result) + 1
                or else not Is_Word_Char (Text (P + Name_Length (Name, With_Result)))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Is_Word_Form (Name);

   function Contains_Name (Text : String; Name : String; With_Result : Boolean) return Boolean is
     ((for some P in 1 .. Text'Length => Name_At (Text, P, Name, With_Result)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Is_Word_Form (Name);

   function Next_Name_At_Or_After (Text : String; Name : String; With_Result : Boolean; From : Positive) return Natural is
     (if From > Text'Length then 0
      elsif Name_At (Text, From, Name, With_Result) then From
      else Next_Name_At_Or_After (Text, Name, With_Result, From + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Is_Word_Form (Name)
                  and then From <= Text'Length + 1,
          Post => (Next_Name_At_Or_After'Result = 0
                   or else (Next_Name_At_Or_After'Result >= From and then Next_Name_At_Or_After'Result <= Text'Length))
                   and then (if Next_Name_At_Or_After'Result > 0 then Name_At (Text, Next_Name_At_Or_After'Result, Name, With_Result)),
          Subprogram_Variant => (Decreases => Text'Length - From + 1);

   function Collapse_From (Text : String; K : Positive; In_Run : Boolean) return String is
     (if K > Text'Length then ""
      elsif Is_Collapse_Space (Text (K)) then
        (if In_Run then Collapse_From (Text, K + 1, True)
         else " " & Collapse_From (Text, K + 1, True))
      else Text (K) & Collapse_From (Text, K + 1, False))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then K <= Text'Length + 1,
          Post => Collapse_From'Result'First = 1
                   and then Collapse_From'Result'Length <= Text'Length - K + 1
                   and then (for all I in Collapse_From'Result'Range =>
                               (Collapse_From'Result (I) /= HT and then Collapse_From'Result (I) /= LF
                                and then Collapse_From'Result (I) /= FF and then Collapse_From'Result (I) /= CR)),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Collapse_Whitespace (Text : String) return String is
     (Collapse_From (Text, 1, False))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Collapse_Whitespace'Result'First = 1
                   and then Collapse_Whitespace'Result'Length <= Text'Length
                   and then (for all I in Collapse_Whitespace'Result'Range =>
                               (Collapse_Whitespace'Result (I) /= HT and then Collapse_Whitespace'Result (I) /= LF
                                and then Collapse_Whitespace'Result (I) /= FF and then Collapse_Whitespace'Result (I) /= CR));

   function Paren_Step (C : Character) return Integer is
     (if C = '(' then 1 elsif C = ')' then -1 else 0)
     with Post => Paren_Step'Result >= -1 and then Paren_Step'Result <= 1;

   function Paren_Depth (S : String; Start : Positive; J : Natural) return Integer is
     (if J < Start then 0
      else Paren_Depth (S, Start, J - 1) + Paren_Step (S (J)))
     with Ghost,
          Pre  => S'First = 1 and then S'Length <= Max_Text and then J <= S'Length,
          Post => (if J < Start then Paren_Depth'Result = 0)
                   and then Paren_Depth'Result >= -J and then Paren_Depth'Result <= J,
          Subprogram_Variant => (Decreases => J);

   function Last_Non_Blank_Before (S : String; J : Positive) return Natural is
     (if J = 1 then 0
      elsif S (J - 1) /= ' ' then J - 1
      else Last_Non_Blank_Before (S, J - 1))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then J <= S'Length + 1,
          Post => Last_Non_Blank_Before'Result < J
                   and then (for all K in Last_Non_Blank_Before'Result + 1 .. J - 1 => S (K) = ' ')
                   and then (if Last_Non_Blank_Before'Result > 0 then S (Last_Non_Blank_Before'Result) /= ' '),
          Subprogram_Variant => (Decreases => J);

   function And_Before (S : String; J : Positive) return Boolean is
     (J >= 5 and then Last_Non_Blank_Before (S, J) >= 3
      and then S (Last_Non_Blank_Before (S, J) - 2 .. Last_Non_Blank_Before (S, J)) = "and")
     with Pre => S'First = 1 and then S'Length <= Max_Text and then J <= S'Length + 1;

   function Then_At (S : String; J : Positive) return Boolean is
     (J + 3 <= S'Length
      and then S (J .. J + 3) = "then"
      and then (J = 1 or else not Is_Word_Char (S (J - 1)))
      and then (J + 4 > S'Length or else not Is_Word_Char (S (J + 4)))
      and then not And_Before (S, J))
     with Pre => S'First = 1 and then S'Length <= Max_Text and then J <= S'Length;

   function Is_Guard_Then (S : String; Start : Positive; J : Positive) return Boolean is
     (J + 3 <= S'Length and then Paren_Depth (S, Start, J) = 0 and then Then_At (S, J))
     with Ghost,
          Pre => S'First = 1 and then S'Length <= Max_Text and then J <= S'Length;

   function Guard_Scan (S : String; Start : Positive; J : Positive; Depth : Depth_Type) return Natural is
     (if J > S'Length - 3 then 0
      elsif Depth + Paren_Step (S (J)) = 0 and then Then_At (S, J) then J
      elsif Depth + Paren_Step (S (J)) < 0 then 0
      else Guard_Scan (S, Start, J + 1, Depth + Paren_Step (S (J))))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Start <= J
                  and then J <= S'Length + 1 and then Depth = Paren_Depth (S, Start, J - 1),
          Post => Guard_Scan'Result = 0
                   or else (Guard_Scan'Result >= J and then Guard_Scan'Result <= S'Length - 3
                            and then Is_Guard_Then (S, Start, Guard_Scan'Result)),
          Subprogram_Variant => (Decreases => S'Length - J + 1);

   function Guard_End (S : String; Start : Positive) return Natural is
     (Guard_Scan (S, Start, Start, 0))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Start <= S'Length + 1,
          Post => Guard_End'Result = 0
                   or else (Guard_End'Result >= Start and then Guard_End'Result <= S'Length - 3
                            and then Is_Guard_Then (S, Start, Guard_End'Result));

   function First_Non_Trim (S : String; From : Positive; Last : Natural) return Positive is
     (if From > Last then Last + 1
      elsif not Is_Trim_Space (S (From)) then From
      else First_Non_Trim (S, From + 1, Last))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Last <= S'Length
                  and then From <= Last + 1,
          Post => First_Non_Trim'Result >= From and then First_Non_Trim'Result <= Last + 1
                   and then (if First_Non_Trim'Result <= Last then not Is_Trim_Space (S (First_Non_Trim'Result))),
          Subprogram_Variant => (Decreases => Last - From + 1);

   function Last_Non_Trim (S : String; First : Positive; Last : Natural) return Natural is
     (if Last < First then First - 1
      elsif not Is_Trim_Space (S (Last)) then Last
      else Last_Non_Trim (S, First, Last - 1))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Last <= S'Length
                  and then First <= Last + 1,
          Post => Last_Non_Trim'Result >= First - 1 and then Last_Non_Trim'Result <= Last
                   and then (if Last_Non_Trim'Result >= First then not Is_Trim_Space (S (Last_Non_Trim'Result))),
          Subprogram_Variant => (Decreases => Last - First + 1);

   function Has_Guard_Keyword (S : String) return Boolean is
     (Keyword_At_Or_After (S, If_Kw, 1) /= 0 or else Keyword_At_Or_After (S, Elsif_Kw, 1) /= 0)
     with Ghost,
          Pre => S'First = 1 and then S'Length <= Max_Text;

   function Guard_Start (S : String; Kw : String; Pos : Positive) return Natural is
     (Keyword_At_Or_After (S, Kw, Pos))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1,
          Post => Guard_Start'Result = 0
                  or else (Guard_Start'Result >= Pos and then Whole_Word_At (S, Guard_Start'Result, Kw));

   function Guard_Stop (S : String; Kw : String; Pos : Positive) return Natural is
     (Guard_End (S, Guard_Start (S, Kw, Pos) + Kw'Length))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1 and then Guard_Start (S, Kw, Pos) /= 0,
          Post => Guard_Stop'Result = 0
                  or else (Guard_Stop'Result >= Guard_Start (S, Kw, Pos) + Kw'Length
                           and then Guard_Stop'Result <= S'Length - 3);

   function Found (S : String; Kw : String; Pos : Positive) return Boolean is
     (Guard_Start (S, Kw, Pos) /= 0 and then Guard_Stop (S, Kw, Pos) /= 0)
     with Pre => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                 and then Pos <= S'Length + 1;

   function Found_First (S : String; Kw : String; Pos : Positive) return Positive is
     (First_Non_Trim (S, Guard_Start (S, Kw, Pos) + Kw'Length, Guard_Stop (S, Kw, Pos) - 1))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1 and then Found (S, Kw, Pos),
          Post => Found_First'Result >= Guard_Start (S, Kw, Pos) + Kw'Length
                  and then Found_First'Result <= Guard_Stop (S, Kw, Pos);

   function Found_Last (S : String; Kw : String; Pos : Positive) return Natural is
     (Last_Non_Trim (S, Found_First (S, Kw, Pos), Guard_Stop (S, Kw, Pos) - 1))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1 and then Found (S, Kw, Pos),
          Post => Found_Last'Result <= Guard_Stop (S, Kw, Pos) - 1
                  and then Found_Last'Result >= Found_First (S, Kw, Pos) - 1;

   function Has_Text (S : String; Kw : String; Pos : Positive) return Boolean is
     (Found_First (S, Kw, Pos) <= Found_Last (S, Kw, Pos))
     with Pre => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                 and then Pos <= S'Length + 1 and then Found (S, Kw, Pos);

   function Resume_At (S : String; Kw : String; Pos : Positive) return Positive is
     (Guard_Stop (S, Kw, Pos) + 4)
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1 and then Found (S, Kw, Pos),
          Post => Resume_At'Result > Pos and then Resume_At'Result <= S'Length + 1;

   function Kw_Count_From (S : String; Kw : String; Pos : Positive) return Natural is
     (if not Found (S, Kw, Pos) then 0
      elsif Has_Text (S, Kw, Pos) then 1 + Kw_Count_From (S, Kw, Resume_At (S, Kw, Pos))
      else Kw_Count_From (S, Kw, Resume_At (S, Kw, Pos)))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1,
          Post => Kw_Count_From'Result <= S'Length - Pos + 1,
          Subprogram_Variant => (Decreases => S'Length - Pos + 1);

   function No_Guard return Guard is
     ((First => 1, Last => 0));

   function Found_Guard (S : String; Kw : String; Pos : Positive) return Guard is
     ((First => Found_First (S, Kw, Pos), Last => Found_Last (S, Kw, Pos)))
     with Pre => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                 and then Pos <= S'Length + 1 and then Found (S, Kw, Pos);

   function Kw_Nth_From (S : String; Kw : String; Pos : Positive; N : Positive) return Guard is
     (if not Found (S, Kw, Pos) then No_Guard
      elsif not Has_Text (S, Kw, Pos) then Kw_Nth_From (S, Kw, Resume_At (S, Kw, Pos), N)
      elsif N = 1 then Found_Guard (S, Kw, Pos)
      else Kw_Nth_From (S, Kw, Resume_At (S, Kw, Pos), N - 1))
     with Pre  => S'First = 1 and then S'Length <= Max_Text and then Is_Word_Form (Kw)
                  and then Pos <= S'Length + 1,
          Post => Kw_Nth_From'Result.Last <= S'Length
                  and then (Kw_Nth_From'Result.First > Kw_Nth_From'Result.Last
                            or else (not Is_Trim_Space (S (Kw_Nth_From'Result.First))
                                     and then not Is_Trim_Space (S (Kw_Nth_From'Result.Last)))),
          Subprogram_Variant => (Decreases => S'Length - Pos + 1);

   function Guard_Count (S : String) return Natural is
     (Kw_Count_From (S, If_Kw, 1) + Kw_Count_From (S, Elsif_Kw, 1))
     with Pre  => S'First = 1 and then S'Length <= Max_Text,
          Post => Guard_Count'Result <= 2 * S'Length;

   function Nth_Guard (S : String; N : Positive) return Guard is
     (if N <= Kw_Count_From (S, If_Kw, 1) then Kw_Nth_From (S, If_Kw, 1, N)
      else Kw_Nth_From (S, Elsif_Kw, 1, N - Kw_Count_From (S, If_Kw, 1)))
     with Pre  => S'First = 1 and then S'Length <= Max_Text,
          Post => Nth_Guard'Result.Last <= S'Length;

end Lovelace_Word_Rules_Pkg;
