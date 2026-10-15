--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: ab730fba95c1963d28a5ee3a4440e9df2325e4c829d7da4ae733dd5165b44e57
--
package body Tower_Scan_Pkg with SPARK_Mode is

   function Key_Position (Line : String; Key : String) return Natural is
   begin
      for I in Line'Range loop
         if Is_Key_At (Line, Key, I) then
            return I;
         end if;
         pragma Loop_Invariant (for all J in Line'First .. I => not Is_Key_At (Line, Key, J));
      end loop;
      return 0;
   end Key_Position;

   function Skip_WS (Line : String; J : Positive) return Natural is
   begin
      for K in J .. Line'Last loop
         if not Is_WS (Line (K)) then
            return K;
         end if;
         pragma Loop_Invariant (WS_From (Line, K + 1) = WS_From (Line, J));
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
         pragma Loop_Invariant (Str_From (Line, K + 1, Esc) = Str_From (Line, Q + 1, False));
      end loop;
      return 0;
   end Str_End;

   function Comp_End (Line : String; F : Positive) return Natural is
      D : Natural := 0;
      S : Bracket_Stack := Empty_Stack;
      In_Str : Boolean := False;
      Esc : Boolean := False;
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
            Esc := False;
         elsif Line (K) = '{' or else Line (K) = '[' then
            if D >= Max_Depth then
               return 0;
            end if;
            S := Push (S, D, Line (K));
            D := D + 1;
         elsif Line (K) = '}' or else Line (K) = ']' then
            if D = 0 then
               return 0;
            elsif (S (D) = '{') /= (Line (K) = '}') then
               return 0;
            elsif D = 1 then
               return K;
            else
               D := D - 1;
            end if;
         end if;
         pragma Loop_Invariant (D <= Max_Depth);
         pragma Loop_Invariant ((if not In_Str then not Esc));
         pragma Loop_Invariant (Comp_From (Line, K + 1, S, D, In_Str, Esc) = Comp_From (Line, F, Empty_Stack, 0, False, False));
      end loop;
      return 0;
   end Comp_End;

   function Bare_End (Line : String; F : Positive) return Natural is
   begin
      if not Is_Bare_Char (Line (F)) then
         return 0;
      end if;

      pragma Assert (Bare_From (Line, F) = Bare_From (Line, F + 1));
      for K in F + 1 .. Line'Last loop
         if not Is_Bare_Char (Line (K)) then
            return K - 1;
         end if;
         pragma Loop_Invariant (Bare_From (Line, K + 1) = Bare_From (Line, F));
      end loop;
      return Line'Last;
   end Bare_End;

   function Key_Equals (Line : String; Q : Positive; E : Positive; Key : String) return Boolean is
      I : Positive := Q + 1;
      K : Positive := Key'First;
   begin
      for Iter in Key'Range loop
         if I >= E then
            return False;
         end if;
         if Line (I) /= '\' then
            if Line (I) /= Key (K) then
               return False;
            end if;
            I := I + 1;
            K := K + 1;
         elsif I + 1 >= E then
            return False;
         elsif Line (I + 1) = 'u' then
            if not (I + 5 < E and then Is_Hex (Line (I + 2)) and then Is_Hex (Line (I + 3))
                    and then Is_Hex (Line (I + 4)) and then Is_Hex (Line (I + 5))
                    and then Hex4 (Line, I + 2) < 128
                    and then Character'Val (Hex4 (Line, I + 2)) = Key (K)) then
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
         pragma Loop_Invariant (K = Iter + 1);
         pragma Loop_Invariant (I <= E);
         pragma Loop_Invariant (Key_From (Line, I, E, Key, K) = Key_From (Line, Q + 1, E, Key, 1));
      end loop;
      return I >= E;
   end Key_Equals;

   function Member_Span (Line : String; Obj : Span_Type; Key : String) return Span_Type is
      P : Positive := Obj.first + 1;
      Acc : Span_Type := No_Span;
      Count : Natural := 0;
   begin
      for Iter in Obj.first + 1 .. Obj.last loop
         declare
            S : constant Natural := Skip_WS (Line, P);
         begin
            if S = 0 or else S >= Obj.last or else Line (S) /= '"' then
               exit;
            end if;

            declare
               KE : constant Natural := Str_End (Line, S);
            begin
               if KE = 0 or else KE >= Obj.last then
                  exit;
               end if;

               declare
                  C : constant Natural := Skip_WS (Line, KE + 1);
               begin
                  if C = 0 or else C >= Obj.last or else Line (C) /= ':' then
                     exit;
                  end if;

                  declare
                     V : constant Natural := Skip_WS (Line, C + 1);
                  begin
                     if V = 0 or else V >= Obj.last then
                        exit;
                     end if;

                     declare
                        VE : constant Natural := Value_End (Line, V);
                     begin
                        if VE = 0 or else VE >= Obj.last then
                           exit;
                        end if;

                        declare
                           Hit : constant Boolean := Key_Equals (Line, S, KE, Key);
                           N : constant Natural := Skip_WS (Line, VE + 1);
                        begin
                           if N = 0 then
                              exit;
                           end if;

                           if Hit then
                              Acc := (found => True, kind => Kind_Of (Line (V)), first => V, last => VE);
                              if Count < 2 then
                                 Count := Count + 1;
                              end if;
                           end if;

                           if N = Obj.last then
                              return (if Count = 1 then Acc else No_Span);
                           elsif N > Obj.last or else Line (N) /= ',' then
                              exit;
                           else
                              P := N + 1;
                           end if;
                        end;
                     end;
                  end;
               end;
            end;
         end;
         pragma Loop_Invariant (P >= Iter + 1);
         pragma Loop_Invariant (P >= Obj.first + 1);
         pragma Loop_Invariant (P <= Obj.last);
         pragma Loop_Invariant (Count <= 2);
         pragma Loop_Invariant ((if not Acc.found then Acc = No_Span));
         pragma Loop_Invariant ((if Acc.found then
                                   Acc.first in Obj.first + 1 .. Obj.last - 1
                                   and then Acc.last in Acc.first .. Obj.last - 1
                                   and then Acc.kind = Kind_Of (Line (Acc.first))
                                   and then not Is_WS (Line (Acc.first))
                                   and then (if Acc.kind = K_String then
                                               Line (Acc.last) = '"'
                                               and then Acc.first < Acc.last)));
         pragma Loop_Invariant (Mem_From (Line, Obj.last, P, Key, Acc, Count) = Mem_From (Line, Obj.last, Obj.first + 1, Key, No_Span, 0));
      end loop;
      return No_Span;
   end Member_Span;

   function Member_Duplicated (Line : String; Obj : Span_Type; Key : String) return Boolean is
      P : Positive := Obj.first + 1;
      Count : Natural := 0;
   begin
      for Iter in Obj.first + 1 .. Obj.last loop
         declare
            S : constant Natural := Skip_WS (Line, P);
         begin
            if S = 0 or else S >= Obj.last or else Line (S) /= '"' then
               exit;
            end if;

            declare
               KE : constant Natural := Str_End (Line, S);
            begin
               if KE = 0 or else KE >= Obj.last then
                  exit;
               end if;

               declare
                  C : constant Natural := Skip_WS (Line, KE + 1);
               begin
                  if C = 0 or else C >= Obj.last or else Line (C) /= ':' then
                     exit;
                  end if;

                  declare
                     V : constant Natural := Skip_WS (Line, C + 1);
                  begin
                     if V = 0 or else V >= Obj.last then
                        exit;
                     end if;

                     declare
                        VE : constant Natural := Value_End (Line, V);
                     begin
                        if VE = 0 or else VE >= Obj.last then
                           exit;
                        end if;

                        declare
                           Hit : constant Boolean := Key_Equals (Line, S, KE, Key);
                           N : constant Natural := Skip_WS (Line, VE + 1);
                        begin
                           if N = 0 then
                              exit;
                           end if;

                           if Hit and then Count < 2 then
                              Count := Count + 1;
                           end if;

                           if N = Obj.last then
                              return Count = 2;
                           elsif N > Obj.last or else Line (N) /= ',' then
                              exit;
                           else
                              P := N + 1;
                           end if;
                        end;
                     end;
                  end;
               end;
            end;
         end;
         pragma Loop_Invariant (P >= Iter + 1);
         pragma Loop_Invariant (P >= Obj.first + 1);
         pragma Loop_Invariant (P <= Obj.last);
         pragma Loop_Invariant (Count <= 2);
         pragma Loop_Invariant (Dup_From (Line, Obj.last, P, Key, Count) = Dup_From (Line, Obj.last, Obj.first + 1, Key, 0));
      end loop;
      return False;
   end Member_Duplicated;

   function Element_Span (Line : String; Arr : Span_Type; Index : Positive) return Span_Type is
      P : Positive := Arr.first + 1;
      I : Positive := 1;
   begin
      for Iter in Arr.first + 1 .. Arr.last loop
         declare
            S : constant Natural := Skip_WS (Line, P);
         begin
            if S = 0 or else S >= Arr.last then
               exit;
            end if;

            declare
               VE : constant Natural := Value_End (Line, S);
            begin
               if VE = 0 or else VE >= Arr.last then
                  exit;
               end if;

               declare
                  N : constant Natural := Skip_WS (Line, VE + 1);
               begin
                  if N = 0 or else (N /= Arr.last and then (N > Arr.last or else Line (N) /= ',')) then
                     exit;
                  end if;

                  if I = Index then
                     return (found => True, kind => Kind_Of (Line (S)), first => S, last => VE);
                  end if;

                  if N = Arr.last then
                     exit;
                  end if;

                  P := N + 1;
                  I := I + 1;
               end;
            end;
         end;
         pragma Loop_Invariant (P >= Iter + 1);
         pragma Loop_Invariant (P >= Arr.first + 1);
         pragma Loop_Invariant (P <= Arr.last);
         pragma Loop_Invariant (I <= Index);
         pragma Loop_Invariant (El_From (Line, Arr.last, P, Index, I) = El_From (Line, Arr.last, Arr.first + 1, Index, 1));
      end loop;
      return No_Span;
   end Element_Span;

   function String_Contents (Line : String; S : Span_Type) return Span_Type is
   begin
      return (found => True, kind => K_String, first => S.first + 1, last => S.last - 1);
   end String_Contents;

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean is
   begin
      if Literal'Length /= S.last - S.first + 1 then
         return False;
      end if;
      return Line (S.first .. S.last) = Literal;
   end Equals_Literal;

end Tower_Scan_Pkg;