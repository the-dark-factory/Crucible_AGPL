--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 48782021c15a42e1661ea2a8e7a797fb0709823bf6d5c5479dd992ec27a4f3a7
--
package Lovelace_Verdict_Reply_Pkg with SPARK_Mode, Pure is

   Max_Reply : constant := 4_096;

   subtype Non_Positive is Long_Long_Integer range Long_Long_Integer'First .. 0;
   subtype Edge_Digit is Natural range 0 .. 2;

   type Exit_Kind is (Exit_Ok, Exit_Two, Exit_Other, Not_Started);

   type Reply_Kind is (Refused, Errored, Unreadable, Number);

   type Parse_Result is record
      Ok    : Boolean           := False;
      Value : Long_Long_Integer := 0;
   end record;

   type Reply is record
      Kind  : Reply_Kind        := Errored;
      Value : Long_Long_Integer := 0;
   end record;

   type Answer is record
      Answered : Boolean    := False;
      Digit    : Edge_Digit := 0;
   end record;

   function Parse_Failed return Parse_Result is
     ((Ok => False, Value => 0));

   function Is_Trim_Space (C : Character) return Boolean is
     (C = Character'Val (9) or else C = Character'Val (10) or else C = Character'Val (11) or else C = Character'Val (12) or else C = Character'Val (13) or else C = ' ')
     with Global => null;

   function First_Non_Trim (Text : String; From : Positive; Last : Natural) return Positive is
     (if From > Last then Last + 1
      elsif not Is_Trim_Space (Text (From)) then From
      else First_Non_Trim (Text, From + 1, Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Reply and then Last <= Text'Length
                  and then From <= Last + 1,
          Post => First_Non_Trim'Result >= From and then First_Non_Trim'Result <= Last + 1,
          Subprogram_Variant => (Decreases => Last - From + 1);

   function Last_Non_Trim (Text : String; First : Positive; Last : Natural) return Natural is
     (if Last < First then First - 1
      elsif not Is_Trim_Space (Text (Last)) then Last
      else Last_Non_Trim (Text, First, Last - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Reply and then Last <= Text'Length
                  and then First <= Last + 1,
          Post => Last_Non_Trim'Result >= First - 1 and then Last_Non_Trim'Result <= Last,
          Subprogram_Variant => (Decreases => Last - First + 1);

   function Is_Digit (C : Character) return Boolean is
     (C in '0' .. '9');

   function Digit_Value (C : Character) return Natural is
     (Character'Pos (C) - Character'Pos ('0'))
     with Pre  => Is_Digit (C),
          Post => Digit_Value'Result <= 9;

   function All_Digits (Text : String; F : Positive; L : Natural) return Boolean is
     (F <= L and then (for all K in F .. L => Is_Digit (Text (K))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Reply and then L <= Text'Length;

   function Fits_Next (V : Non_Positive; D : Natural) return Boolean is
     (V >= (Long_Long_Integer'First + Long_Long_Integer (D)) / 10)
     with Pre => D <= 9;

   function Neg_Accumulate (Text : String; F : Positive; L : Natural; V : Non_Positive) return Parse_Result is
     (if F > L then (Ok => True, Value => V)
      elsif not Fits_Next (V, Digit_Value (Text (F))) then Parse_Failed
      else Neg_Accumulate (Text, F + 1, L, V * 10 - Long_Long_Integer (Digit_Value (Text (F)))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Reply and then L <= Text'Length
                  and then F <= L + 1 and then (for all K in F .. L => Is_Digit (Text (K))),
          Post => (if Neg_Accumulate'Result.Ok then Neg_Accumulate'Result.Value <= 0),
          Subprogram_Variant => (Decreases => L - F + 1);

   function Sign_Length (Text : String; F : Positive; L : Natural) return Natural is
     (if F <= L and then (Text (F) = '+' or else Text (F) = '-') then 1 else 0)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Reply and then L <= Text'Length,
          Post => Sign_Length'Result <= 1 and then (if Sign_Length'Result = 1 then F <= L);

   function Is_Negative (Text : String; F : Positive; L : Natural) return Boolean is
     (F <= L and then Text (F) = '-')
     with Pre => Text'First = 1 and then Text'Length <= Max_Reply and then L <= Text'Length;

   function Magnitude (Text : String; F : Positive; L : Natural) return Parse_Result is
     (Neg_Accumulate (Text, F + Sign_Length (Text, F, L), L, 0))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Reply and then L <= Text'Length
                  and then F <= L + 1 and then All_Digits (Text, F + Sign_Length (Text, F, L), L),
          Post => (if Magnitude'Result.Ok then Magnitude'Result.Value <= 0);

   function Atoi (Text : String; F : Positive; L : Natural) return Parse_Result is
     (if not All_Digits (Text, F + Sign_Length (Text, F, L), L) then Parse_Failed
      elsif not Magnitude (Text, F, L).Ok then Parse_Failed
      elsif Is_Negative (Text, F, L) then Magnitude (Text, F, L)
      elsif Magnitude (Text, F, L).Value = Long_Long_Integer'First then Parse_Failed
      else (Ok => True, Value => -Magnitude (Text, F, L).Value))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Reply and then L <= Text'Length
                  and then F <= L + 1,
          Post => (if Atoi'Result.Ok then All_Digits (Text, F + Sign_Length (Text, F, L), L))
                  and then (if Atoi'Result.Ok and then not Is_Negative (Text, F, L) then Atoi'Result.Value >= 0);

   function Word_First (Output : String) return Positive is
     (First_Non_Trim (Output, 1, Output'Length))
     with Pre  => Output'First = 1 and then Output'Length <= Max_Reply,
          Post => Word_First'Result <= Output'Length + 1;

   function Word_Last (Output : String) return Natural is
     (Last_Non_Trim (Output, Word_First (Output), Output'Length))
     with Pre  => Output'First = 1 and then Output'Length <= Max_Reply,
          Post => Word_Last'Result <= Output'Length and then Word_Last'Result >= Word_First (Output) - 1;

   function Reply_Of (Status : Exit_Kind; Output : String) return Reply is
     (if Status = Exit_Two then (Kind => Refused, Value => 0)
      elsif Status /= Exit_Ok then (Kind => Errored, Value => 0)
      elsif not Atoi (Output, Word_First (Output), Word_Last (Output)).Ok then (Kind => Unreadable, Value => 0)
      else (Kind => Number, Value => Atoi (Output, Word_First (Output), Word_Last (Output)).Value))
     with Pre  => Output'First = 1 and then Output'Length <= Max_Reply,
          Post => ((Reply_Of'Result.Kind = Refused) = (Status = Exit_Two))
                  and then ((Reply_Of'Result.Kind = Errored) = (Status = Exit_Other or else Status = Not_Started))
                  and then (if Reply_Of'Result.Kind = Number then Status = Exit_Ok);

   function Answer_Of (R : Reply) return Answer is
     (if R.Kind = Number and then R.Value >= 0 and then R.Value <= 2
      then (Answered => True, Digit => Edge_Digit (R.Value))
      else (Answered => False, Digit => 0))
     with Post => ((Answer_Of'Result.Answered) = (R.Kind = Number and then R.Value >= 0 and then R.Value <= 2))
                  and then (if Answer_Of'Result.Answered then Long_Long_Integer (Answer_Of'Result.Digit) = R.Value);

end Lovelace_Verdict_Reply_Pkg;
