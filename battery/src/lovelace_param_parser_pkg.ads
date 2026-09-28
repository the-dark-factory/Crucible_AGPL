--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5fa519afe6fd068543f407442a3f7f8bd6a6c1713255d2cae59c4c1e6556e2fe
--
package Lovelace_Param_Parser_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;

   type Param_Bounds is record
      Name_First : Positive := 1;
      Name_Last  : Natural  := 0;
      Type_First : Positive := 1;
      Type_Last  : Natural  := 0;
   end record;

   function No_Param return Param_Bounds is
     ((Name_First => 1, Name_Last => 0, Type_First => 1, Type_Last => 0));

   function Is_Trim_Space (C : Character) return Boolean is
     (C = Character'Val (9) or else C = Character'Val (10) or else C = Character'Val (11) or else C = Character'Val (12) or else C = Character'Val (13) or else C = ' ')
     with Global => null;

   function All_Trim_Between (Text : String; From : Positive; To : Natural) return Boolean is
     ((for all K in From .. To => Is_Trim_Space (Text (K))))
     with Pre => Text'First = 1 and then To <= Text'Length;

   function Ends_Not_Trim (Text : String; First : Positive; Last : Natural) return Boolean is
     (if First <= Last then
        (not Is_Trim_Space (Text (First)) and then not Is_Trim_Space (Text (Last))))
     with Pre => Text'First = 1 and then Last <= Text'Length;

   function First_Non_Trim (Text : String; From : Positive; Last : Natural) return Positive is
     (if From > Last then Last + 1
      elsif not Is_Trim_Space (Text (From)) then From
      else First_Non_Trim (Text, From + 1, Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then From <= Last + 1,
          Post => First_Non_Trim'Result >= From and then First_Non_Trim'Result <= Last + 1
                  and then All_Trim_Between (Text, From, First_Non_Trim'Result - 1)
                  and then (if First_Non_Trim'Result <= Last then not Is_Trim_Space (Text (First_Non_Trim'Result))),
          Subprogram_Variant => (Decreases => Last - From + 1);

   function Last_Non_Trim (Text : String; First : Positive; Last : Natural) return Natural is
     (if Last < First then First - 1
      elsif not Is_Trim_Space (Text (Last)) then Last
      else Last_Non_Trim (Text, First, Last - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then First <= Last + 1,
          Post => Last_Non_Trim'Result >= First - 1 and then Last_Non_Trim'Result <= Last
                  and then All_Trim_Between (Text, Last_Non_Trim'Result + 1, Last)
                  and then (if Last_Non_Trim'Result >= First then not Is_Trim_Space (Text (Last_Non_Trim'Result))),
          Subprogram_Variant => (Decreases => Last - First + 1);

   function No_Char_Between (Text : String; C : Character; From : Positive; To : Natural) return Boolean is
     ((for all K in From .. To => Text (K) /= C))
     with Pre => Text'First = 1 and then To <= Text'Length;

   function Find (Text : String; C : Character; From : Positive; Last : Natural) return Natural is
     (if From > Last then 0
      elsif Text (From) = C then From
      else Find (Text, C, From + 1, Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then From <= Last + 1,
          Post => (if Find'Result = 0 then No_Char_Between (Text, C, From, Last)
                   else (Find'Result >= From and then Find'Result <= Last and then Text (Find'Result) = C
                         and then No_Char_Between (Text, C, From, Find'Result - 1))),
          Subprogram_Variant => (Decreases => Last - From + 1);

   function Stop_Before (Text : String; C : Character; From : Positive; Last : Natural) return Natural is
     (if Find (Text, C, From, Last) = 0 then Last else Find (Text, C, From, Last) - 1)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then From <= Last + 1,
          Post => Stop_Before'Result >= From - 1 and then Stop_Before'Result <= Last
                  and then No_Char_Between (Text, C, From, Stop_Before'Result)
                  and then (Stop_Before'Result = Last or else Text (Stop_Before'Result + 1) = C);

   function Name_Stop (Text : String; K : Positive; Names_Last : Natural) return Natural is
     (Stop_Before (Text, ',', K, Names_Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Names_Last <= Text'Length
                  and then K <= Names_Last + 1,
          Post => Name_Stop'Result >= K - 1 and then Name_Stop'Result <= Names_Last;

   function Group_Stop (Text : String; G : Positive) return Natural is
     (Stop_Before (Text, ';', G, Text'Length))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then G <= Text'Length + 1,
          Post => Group_Stop'Result >= G - 1 and then Group_Stop'Result <= Text'Length;

   function Trimmed_Last (Text : String; From : Positive; Last : Natural) return Natural is
     (Last_Non_Trim (Text, First_Non_Trim (Text, From, Last), Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then From <= Last + 1,
          Post => Trimmed_Last'Result <= Last
                  and then Trimmed_Last'Result >= First_Non_Trim (Text, From, Last) - 1;

   function Piece_Weight (Text : String; K : Positive; E : Natural) return Natural is
     (if First_Non_Trim (Text, K, E) <= E then 1 else 0)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then E <= Text'Length
                  and then K <= E + 1,
          Post => Piece_Weight'Result <= 1;

   function Name_Count (Text : String; K : Positive; Names_Last : Natural) return Natural is
     (if Name_Stop (Text, K, Names_Last) = Names_Last
      then Piece_Weight (Text, K, Names_Last)
      else Piece_Weight (Text, K, Name_Stop (Text, K, Names_Last))
           + Name_Count (Text, Name_Stop (Text, K, Names_Last) + 2, Names_Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Names_Last <= Text'Length
                  and then K <= Names_Last + 1,
          Post => Name_Count'Result <= Names_Last - K + 2,
          Subprogram_Variant => (Decreases => Names_Last - K + 1);

   function Group_Params (Text : String; G : Positive; Group_Last : Natural) return Natural is
     (if Find (Text, ':', G, Group_Last) = 0 then 0
      else Name_Count (Text, G, Find (Text, ':', G, Group_Last) - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Group_Last <= Text'Length
                  and then G <= Group_Last + 1,
          Post => Group_Params'Result <= Group_Last - G + 2;

   function Param_Count_From (Text : String; G : Positive) return Natural is
     (if Group_Stop (Text, G) = Text'Length
      then Group_Params (Text, G, Text'Length)
      else Group_Params (Text, G, Group_Stop (Text, G))
           + Param_Count_From (Text, Group_Stop (Text, G) + 2))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then G <= Text'Length + 1,
          Post => Param_Count_From'Result <= Text'Length - G + 2,
          Subprogram_Variant => (Decreases => Text'Length - G + 1);

   function Param_Count (Text : String) return Natural is
     (Param_Count_From (Text, 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Param_Count'Result <= Text'Length + 1;

   function Name_Of (Text : String; K : Positive; E : Natural) return Param_Bounds is
     ((Name_First => First_Non_Trim (Text, K, E),
       Name_Last  => Trimmed_Last (Text, K, E),
       Type_First => 1,
       Type_Last  => 0))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E <= Text'Length
                 and then K <= E + 1;

   function Nth_Name (Text : String; K : Positive; Names_Last : Natural; N : Positive) return Param_Bounds is
     (if N = 1 and then Piece_Weight (Text, K, Name_Stop (Text, K, Names_Last)) = 1
      then Name_Of (Text, K, Name_Stop (Text, K, Names_Last))
      elsif Name_Stop (Text, K, Names_Last) = Names_Last then No_Param
      elsif Piece_Weight (Text, K, Name_Stop (Text, K, Names_Last)) = 1
      then Nth_Name (Text, Name_Stop (Text, K, Names_Last) + 2, Names_Last, N - 1)
      else Nth_Name (Text, Name_Stop (Text, K, Names_Last) + 2, Names_Last, N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Names_Last <= Text'Length
                  and then K <= Names_Last + 1,
          Post => Nth_Name'Result.Name_First > Nth_Name'Result.Name_Last
                  or else (Nth_Name'Result.Name_First >= K and then Nth_Name'Result.Name_Last <= Names_Last
                           and then Ends_Not_Trim (Text, Nth_Name'Result.Name_First, Nth_Name'Result.Name_Last)),
          Subprogram_Variant => (Decreases => Names_Last - K + 1);

   function With_Type (Text : String; P : Param_Bounds; Colon : Positive; Group_Last : Natural) return Param_Bounds is
     (if P.Name_First > P.Name_Last then No_Param
      else (Name_First => P.Name_First,
            Name_Last  => P.Name_Last,
            Type_First => First_Non_Trim (Text, Colon + 1, Group_Last),
            Type_Last  => Trimmed_Last (Text, Colon + 1, Group_Last)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Group_Last <= Text'Length
                  and then Colon <= Group_Last,
          Post => With_Type'Result.Type_Last <= Group_Last;

   function Nth_In_Group (Text : String; G : Positive; Group_Last : Natural; N : Positive) return Param_Bounds is
     (if Find (Text, ':', G, Group_Last) = 0 then No_Param
      else With_Type (Text, Nth_Name (Text, G, Find (Text, ':', G, Group_Last) - 1, N),
                      Find (Text, ':', G, Group_Last), Group_Last))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Group_Last <= Text'Length
                 and then G <= Group_Last + 1;

   function Nth_Param_From (Text : String; G : Positive; N : Positive) return Param_Bounds is
     (if N <= Group_Params (Text, G, Group_Stop (Text, G))
      then Nth_In_Group (Text, G, Group_Stop (Text, G), N)
      elsif Group_Stop (Text, G) = Text'Length then No_Param
      else Nth_Param_From (Text, Group_Stop (Text, G) + 2,
                           N - Group_Params (Text, G, Group_Stop (Text, G))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then G <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - G + 1);

   function Nth_Param (Text : String; N : Positive) return Param_Bounds is
     (Nth_Param_From (Text, 1, N))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text;

end Lovelace_Param_Parser_Pkg;
