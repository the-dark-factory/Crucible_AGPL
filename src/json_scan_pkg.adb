--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b642c73d5f5d539d1fb367c4ee7d28b0916977ada82c67cb97eda2cf7ac45cd2
--
package body Json_Scan_Pkg with SPARK_Mode is

   function Key_Position (Line : String; Key : String) return Natural is
   begin
      for I in Line'Range loop
         pragma Loop_Invariant (No_Key_Before (Line, Key, I));
         if Is_Key_At (Line, Key, I) then
            return I;
         end if;
      end loop;
      return 0;
   end Key_Position;


   --  Lineage 5: the JSON lookup. Each loop carries the equality of its model at the start
   --  with the same model in the loop's current state; the executable steps mirror the model.

   function Skip_WS (Line : String; J : Positive) return Natural is
   begin
      for K in J .. Line'Last loop
         if not Is_WS (Line (K)) then
            return K;
         end if;
         pragma Loop_Invariant (WS_From (Line, J) = WS_From (Line, K + 1));
      end loop;
      return 0;
   end Skip_WS;

   function Str_End (Line : String; Q : Positive) return Natural is
      Esc : Boolean := False;
   begin
      for K in Q + 1 .. Line'Last loop
         if Esc then
            Esc := False;
         elsif Line (K) = '\' then
            Esc := True;
         elsif Line (K) = '"' then
            return K;
         end if;
         pragma Loop_Invariant (Str_From (Line, Q + 1, False) = Str_From (Line, K + 1, Esc));
      end loop;
      return 0;
   end Str_End;

   function Comp_End (Line : String; F : Positive) return Natural is
      S      : Bracket_Stack := Empty_Stack;
      D      : Natural := 0;
      In_Str : Boolean := False;
      Esc    : Boolean := False;
   begin
      for K in F .. Line'Last loop
         if In_Str then
            if Esc then
               Esc := False;
            elsif Line (K) = '\' then
               Esc := True;
            elsif Line (K) = '"' then
               In_Str := False;
            end if;
         elsif Line (K) = '"' then
            In_Str := True;
         elsif Line (K) = '{' or else Line (K) = '[' then
            if D >= Max_Depth then
               return 0;
            end if;
            S := Push (S, D, Line (K));
            D := D + 1;
         elsif Line (K) = '}' or else Line (K) = ']' then
            if D = 0 then
               return 0;
            end if;
            if (S (D) = '{') /= (Line (K) = '}') then
               return 0;
            end if;
            if D = 1 then
               return K;
            end if;
            D := D - 1;
         end if;
         pragma Loop_Invariant (D <= Max_Depth);
         pragma Loop_Invariant (if not In_Str then not Esc);
         pragma Loop_Invariant
           (Comp_From (Line, F, Empty_Stack, 0, False, False)
              = Comp_From (Line, K + 1, S, D, In_Str, Esc));
      end loop;
      return 0;
   end Comp_End;

   function Bare_End (Line : String; F : Positive) return Natural is
   begin
      if not Is_Bare_Char (Line (F)) then
         return 0;
      end if;
      for K in F + 1 .. Line'Last loop
         if not Is_Bare_Char (Line (K)) then
            return K - 1;
         end if;
         pragma Loop_Invariant (Bare_From (Line, F) = Bare_From (Line, K + 1));
      end loop;
      return Line'Last;
   end Bare_End;

   function Key_Equals (Line : String; Q : Positive; E : Positive; Key : String) return Boolean is
      I : Positive := Q + 1;
      K : Positive := 1;
   begin
      while I < E loop
         pragma Loop_Invariant (I - 1 <= E and then K - 1 <= Key'Last);
         pragma Loop_Invariant (Key_From (Line, Q + 1, E, Key, 1) = Key_From (Line, I, E, Key, K));
         pragma Loop_Variant (Increases => I);
         if K > Key'Last then
            return False;
         elsif Line (I) /= '\' then
            if Line (I) /= Key (K) then
               return False;
            end if;
            I := I + 1;
            K := K + 1;
         elsif I + 1 >= E then
            return False;
         elsif Line (I + 1) = 'u' then
            if not (I + 5 < E
                    and then Is_Hex (Line (I + 2)) and then Is_Hex (Line (I + 3))
                    and then Is_Hex (Line (I + 4)) and then Is_Hex (Line (I + 5))
                    and then Hex4 (Line, I + 2) < 128
                    and then Character'Val (Hex4 (Line, I + 2)) = Key (K))
            then
               return False;
            end if;
            I := I + 6;
            K := K + 1;
         else
            if Unescape (Line (I + 1)) = Character'Val (0) or else Unescape (Line (I + 1)) /= Key (K) then
               return False;
            end if;
            I := I + 2;
            K := K + 1;
         end if;
      end loop;
      return K > Key'Last;
   end Key_Equals;

   function Member_Span (Line : String; Obj : Span_Type; Key : String) return Span_Type is
      P     : Positive;
      Acc   : Span_Type := No_Span;
      Count : Natural := 0;
      S, KE, C, V, VE, N : Natural;
      Hit   : Boolean;
   begin
      if Skip_WS (Line, Obj.first + 1) = Obj.last then
         return No_Span;
      end if;
      P := Obj.first + 1;
      loop
         pragma Loop_Invariant (P in Obj.first + 1 .. Obj.last);
         pragma Loop_Invariant (Count <= 2);
         pragma Loop_Invariant (if Count = 0 then Acc = No_Span);
         pragma Loop_Invariant
           (if Count >= 1 then
              Acc.found
              and then Acc.first in Obj.first + 1 .. Obj.last - 1
              and then Acc.last in Acc.first .. Obj.last - 1
              and then Acc.kind = Kind_Of (Line (Acc.first))
              and then not Is_WS (Line (Acc.first))
              and then (if Acc.kind = K_String then Line (Acc.last) = '"' and then Acc.first < Acc.last));
         pragma Loop_Invariant
           (Mem_From (Line, Obj.last, Obj.first + 1, Key, No_Span, 0)
              = Mem_From (Line, Obj.last, P, Key, Acc, Count));
         pragma Loop_Variant (Increases => P);
         S := Skip_WS (Line, P);
         if S = 0 or else S >= Obj.last or else Line (S) /= '"' then
            return No_Span;
         end if;
         KE := Str_End (Line, S);
         if KE = 0 or else KE >= Obj.last then
            return No_Span;
         end if;
         C := Skip_WS (Line, KE + 1);
         if C = 0 or else C >= Obj.last or else Line (C) /= ':' then
            return No_Span;
         end if;
         V := Skip_WS (Line, C + 1);
         if V = 0 or else V >= Obj.last then
            return No_Span;
         end if;
         VE := Value_End (Line, V);
         if VE = 0 or else VE >= Obj.last then
            return No_Span;
         end if;
         Hit := Key_Equals (Line, S, KE, Key);
         N := Skip_WS (Line, VE + 1);
         if Hit then
            Acc := (found => True, kind => Kind_Of (Line (V)), first => V, last => VE);
            if Count < 2 then
               Count := Count + 1;
            end if;
         end if;
         if N = 0 then
            return No_Span;
         elsif N = Obj.last then
            if Count = 1 then
               return Acc;
            else
               return No_Span;
            end if;
         elsif N < Obj.last and then Line (N) = ',' then
            P := N + 1;
         else
            return No_Span;
         end if;
      end loop;
   end Member_Span;

   function Member_Duplicated (Line : String; Obj : Span_Type; Key : String) return Boolean is
      P     : Positive;
      Count : Natural := 0;
      S, KE, C, V, VE, N : Natural;
      Hit   : Boolean;
   begin
      if Skip_WS (Line, Obj.first + 1) = Obj.last then
         return False;
      end if;
      P := Obj.first + 1;
      loop
         pragma Loop_Invariant (P in Obj.first + 1 .. Obj.last);
         pragma Loop_Invariant (Count <= 2);
         pragma Loop_Invariant
           (Dup_From (Line, Obj.last, Obj.first + 1, Key, 0)
              = Dup_From (Line, Obj.last, P, Key, Count));
         pragma Loop_Variant (Increases => P);
         S := Skip_WS (Line, P);
         if S = 0 or else S >= Obj.last or else Line (S) /= '"' then
            return False;
         end if;
         KE := Str_End (Line, S);
         if KE = 0 or else KE >= Obj.last then
            return False;
         end if;
         C := Skip_WS (Line, KE + 1);
         if C = 0 or else C >= Obj.last or else Line (C) /= ':' then
            return False;
         end if;
         V := Skip_WS (Line, C + 1);
         if V = 0 or else V >= Obj.last then
            return False;
         end if;
         VE := Value_End (Line, V);
         if VE = 0 or else VE >= Obj.last then
            return False;
         end if;
         Hit := Key_Equals (Line, S, KE, Key);
         N := Skip_WS (Line, VE + 1);
         if Hit and then Count < 2 then
            Count := Count + 1;
         end if;
         if N = 0 then
            return False;
         elsif N = Obj.last then
            return Count = 2;
         elsif N < Obj.last and then Line (N) = ',' then
            P := N + 1;
         else
            return False;
         end if;
      end loop;
   end Member_Duplicated;

   function Element_Span (Line : String; Arr : Span_Type; Index : Positive) return Span_Type is
      P : Positive;
      I : Positive := 1;
      S, VE, N : Natural;
   begin
      if Skip_WS (Line, Arr.first + 1) = Arr.last then
         return No_Span;
      end if;
      P := Arr.first + 1;
      loop
         pragma Loop_Invariant (P in Arr.first + 1 .. Arr.last);
         pragma Loop_Invariant (I <= Index);
         pragma Loop_Invariant
           (El_From (Line, Arr.last, Arr.first + 1, Index, 1) = El_From (Line, Arr.last, P, Index, I));
         pragma Loop_Variant (Increases => P);
         S := Skip_WS (Line, P);
         if S = 0 or else S >= Arr.last then
            return No_Span;
         end if;
         VE := Value_End (Line, S);
         if VE = 0 or else VE >= Arr.last then
            return No_Span;
         end if;
         N := Skip_WS (Line, VE + 1);
         if N = 0 or else (N /= Arr.last and then (N > Arr.last or else Line (N) /= ',')) then
            return No_Span;
         elsif I = Index then
            return (found => True, kind => Kind_Of (Line (S)), first => S, last => VE);
         elsif N = Arr.last then
            return No_Span;
         end if;
         P := N + 1;
         I := I + 1;
      end loop;
   end Element_Span;


   function String_Contents (Line : String; S : Span_Type) return Span_Type is
   begin
      return (found => True, kind => K_String, first => S.first + 1, last => S.last - 1);
   end String_Contents;

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean is
   begin
      return (Literal'Length = S.last - S.first + 1) and then (Line (S.first .. S.last) = Literal);
   end Equals_Literal;

end Json_Scan_Pkg;