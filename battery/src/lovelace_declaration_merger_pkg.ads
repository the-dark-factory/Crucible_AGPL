--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 6ffaff4e71dac4b3d3b93b0f9cc14d20049275f2ed8ec9540757c52e6d58b552
--
package Lovelace_Declaration_Merger_Pkg with SPARK_Mode, Pure is

   Max_Text       : constant := 1_048_576;
   Max_Constructs : constant := 10_000;

   type Construct is record
      Name_First    : Positive := 1;
      Name_Last     : Natural  := 0;
      Is_Completion : Boolean  := False;
      Has_Pre       : Boolean  := False;
      Has_Post      : Boolean  := False;
      Has_Aspects   : Boolean  := False;
   end record;

   type Construct_Array is array (Positive range <>) of Construct;

   No_Functions_Prefix : constant String := "no functions found in package ";

   function Name_In (Names : String; C : Construct) return Boolean is
     (C.Name_Last <= Names'Length and then C.Name_First <= C.Name_Last + 1)
     with Pre => Names'First = 1 and then Names'Length <= Max_Text;

   function All_Names_In (Names : String; Cs : Construct_Array) return Boolean is
     ((for all K in Cs'Range => Name_In (Names, Cs (K))))
     with Pre => Names'First = 1 and then Names'Length <= Max_Text;

   function Valid (Names : String; Cs : Construct_Array) return Boolean is
     (Names'First = 1 and then Names'Length <= Max_Text
      and then Cs'First = 1 and then Cs'Length <= Max_Constructs
      and then All_Names_In (Names, Cs));

   function Same_Name (Names : String; Cs : Construct_Array; J : Positive; K : Positive) return Boolean is
     (Names (Cs (J).Name_First .. Cs (J).Name_Last) = Names (Cs (K).Name_First .. Cs (K).Name_Last))
     with Pre => Valid (Names, Cs) and then J <= Cs'Length and then K <= Cs'Length;

   function First_From (Names : String; Cs : Construct_Array; J : Positive; K : Positive) return Positive is
     (if J >= K then K
      elsif Same_Name (Names, Cs, J, K) then J
      else First_From (Names, Cs, J + 1, K))
     with Pre  => Valid (Names, Cs) and then K <= Cs'Length and then J <= K,
          Post => First_From'Result >= J and then First_From'Result <= K
                  and then (First_From'Result = K or else Same_Name (Names, Cs, First_From'Result, K)),
          Subprogram_Variant => (Decreases => K - J);

   function Is_New (Names : String; Cs : Construct_Array; K : Positive) return Boolean is
     (First_From (Names, Cs, 1, K) = K)
     with Pre => Valid (Names, Cs) and then K <= Cs'Length;

   function New_Count (Names : String; Cs : Construct_Array; N : Natural) return Natural is
     (if N = 0 then 0
      elsif Is_New (Names, Cs, N) then New_Count (Names, Cs, N - 1) + 1
      else New_Count (Names, Cs, N - 1))
     with Pre  => Valid (Names, Cs) and then N <= Cs'Length,
          Post => New_Count'Result <= N and then (if N >= 1 then New_Count'Result >= 1),
          Subprogram_Variant => (Decreases => N);

   function Entry_Count (Names : String; Cs : Construct_Array) return Natural is
     (New_Count (Names, Cs, Cs'Length))
     with Pre  => Valid (Names, Cs),
          Post => Entry_Count'Result <= Cs'Length
                  and then ((Entry_Count'Result = 0) = (Cs'Length = 0));

   function Nth_New_From (Names : String; Cs : Construct_Array; K : Positive; N : Positive) return Natural is
     (if K > Cs'Length then 0
      elsif not Is_New (Names, Cs, K) then Nth_New_From (Names, Cs, K + 1, N)
      elsif N = 1 then K
      else Nth_New_From (Names, Cs, K + 1, N - 1))
     with Pre  => Valid (Names, Cs) and then K <= Cs'Length + 1,
          Post => Nth_New_From'Result = 0
                  or else (Nth_New_From'Result >= K and then Nth_New_From'Result <= Cs'Length
                           and then Is_New (Names, Cs, Nth_New_From'Result)),
          Subprogram_Variant => (Decreases => Cs'Length - K + 1);

   function Entry_Construct (Names : String; Cs : Construct_Array; N : Positive) return Natural is
     (Nth_New_From (Names, Cs, 1, N))
     with Pre  => Valid (Names, Cs),
          Post => Entry_Construct'Result = 0
                  or else (Entry_Construct'Result <= Cs'Length and then Is_New (Names, Cs, Entry_Construct'Result));

   function Same_Entry (Names : String; Cs : Construct_Array; F : Positive; J : Positive) return Boolean is
     (J = F or else Same_Name (Names, Cs, F, J))
     with Pre => Valid (Names, Cs) and then F <= Cs'Length and then J <= Cs'Length;

   function Keep_Or (Prev : Natural; J : Positive; Has : Boolean) return Natural is
     (if Prev /= 0 then Prev elsif Has then J else 0)
     with Post => (if Prev /= 0 then Keep_Or'Result = Prev)
                  and then (Keep_Or'Result = 0 or else Keep_Or'Result = Prev
                            or else (Keep_Or'Result = J and then Has));

   function Aspects_Pick (Cs : Construct_Array; Prev : Positive; J : Positive) return Positive is
     (if Cs (Prev).Has_Aspects then Prev else J)
     with Pre  => Cs'First = 1 and then Prev <= Cs'Length and then J <= Cs'Length,
          Post => (if Cs (Prev).Has_Aspects then Aspects_Pick'Result = Prev)
                  and then (Aspects_Pick'Result = Prev or else Aspects_Pick'Result = J);

   function Pre_After (Names : String; Cs : Construct_Array; F : Positive; J : Positive) return Natural is
     (if J <= F then (if Cs (F).Has_Pre then F else 0)
      elsif not Same_Entry (Names, Cs, F, J) then Pre_After (Names, Cs, F, J - 1)
      elsif not Cs (J).Is_Completion then (if Cs (J).Has_Pre then J else 0)
      else Keep_Or (Pre_After (Names, Cs, F, J - 1), J, Cs (J).Has_Pre))
     with Pre  => Valid (Names, Cs) and then F <= Cs'Length and then J <= Cs'Length,
          Post => Pre_After'Result = 0
                  or else (Pre_After'Result >= F and then Pre_After'Result <= Integer'Max (F, J)
                           and then Cs (Pre_After'Result).Has_Pre
                           and then Same_Entry (Names, Cs, F, Pre_After'Result)),
          Subprogram_Variant => (Decreases => J);

   function Post_After (Names : String; Cs : Construct_Array; F : Positive; J : Positive) return Natural is
     (if J <= F then (if Cs (F).Has_Post then F else 0)
      elsif not Same_Entry (Names, Cs, F, J) then Post_After (Names, Cs, F, J - 1)
      elsif not Cs (J).Is_Completion then (if Cs (J).Has_Post then J else 0)
      else Keep_Or (Post_After (Names, Cs, F, J - 1), J, Cs (J).Has_Post))
     with Pre  => Valid (Names, Cs) and then F <= Cs'Length and then J <= Cs'Length,
          Post => Post_After'Result = 0
                  or else (Post_After'Result >= F and then Post_After'Result <= Integer'Max (F, J)
                           and then Cs (Post_After'Result).Has_Post
                           and then Same_Entry (Names, Cs, F, Post_After'Result)),
          Subprogram_Variant => (Decreases => J);

   function Aspects_After (Names : String; Cs : Construct_Array; F : Positive; J : Positive) return Positive is
     (if J <= F then F
      elsif not Same_Entry (Names, Cs, F, J) then Aspects_After (Names, Cs, F, J - 1)
      elsif not Cs (J).Is_Completion then Aspects_After (Names, Cs, F, J - 1)
      else Aspects_Pick (Cs, Aspects_After (Names, Cs, F, J - 1), J))
     with Pre  => Valid (Names, Cs) and then F <= Cs'Length and then J <= Cs'Length,
          Post => Aspects_After'Result >= F and then Aspects_After'Result <= Integer'Max (F, J)
                  and then Same_Entry (Names, Cs, F, Aspects_After'Result),
          Subprogram_Variant => (Decreases => J);

   function Last_Completion (Names : String; Cs : Construct_Array; F : Positive; J : Natural) return Natural is
     (if J < F then 0
      elsif Same_Entry (Names, Cs, F, J) and then Cs (J).Is_Completion then J
      else Last_Completion (Names, Cs, F, J - 1))
     with Pre  => Valid (Names, Cs) and then F <= Cs'Length and then J <= Cs'Length,
          Post => Last_Completion'Result = 0
                  or else (Last_Completion'Result >= F and then Last_Completion'Result <= J
                           and then Cs (Last_Completion'Result).Is_Completion
                           and then Same_Entry (Names, Cs, F, Last_Completion'Result)),
          Subprogram_Variant => (Decreases => J);

   function Last_Declaration (Names : String; Cs : Construct_Array; F : Positive; J : Natural) return Positive is
     (if J <= F then F
      elsif Same_Entry (Names, Cs, F, J) and then not Cs (J).Is_Completion then J
      else Last_Declaration (Names, Cs, F, J - 1))
     with Pre  => Valid (Names, Cs) and then F <= Cs'Length and then J <= Cs'Length,
          Post => Last_Declaration'Result >= F and then Last_Declaration'Result <= Integer'Max (F, J)
                  and then (Last_Declaration'Result = F or else not Cs (Last_Declaration'Result).Is_Completion)
                  and then Same_Entry (Names, Cs, F, Last_Declaration'Result),
          Subprogram_Variant => (Decreases => J);

   function Pre_Source (Names : String; Cs : Construct_Array; F : Positive) return Natural is
     (Pre_After (Names, Cs, F, Cs'Length))
     with Pre => Valid (Names, Cs) and then F <= Cs'Length;

   function Post_Source (Names : String; Cs : Construct_Array; F : Positive) return Natural is
     (Post_After (Names, Cs, F, Cs'Length))
     with Pre => Valid (Names, Cs) and then F <= Cs'Length;

   function Aspects_Source (Names : String; Cs : Construct_Array; F : Positive) return Positive is
     (Aspects_After (Names, Cs, F, Cs'Length))
     with Pre => Valid (Names, Cs) and then F <= Cs'Length;

   function Body_Source (Names : String; Cs : Construct_Array; F : Positive) return Natural is
     (Last_Completion (Names, Cs, F, Cs'Length))
     with Pre => Valid (Names, Cs) and then F <= Cs'Length;

   function Decl_Source (Names : String; Cs : Construct_Array; F : Positive) return Positive is
     (Last_Declaration (Names, Cs, F, Cs'Length))
     with Pre => Valid (Names, Cs) and then F <= Cs'Length;

   function Is_Combined (Cs : Construct_Array; F : Positive) return Boolean is
     (Cs (F).Is_Completion)
     with Pre => Cs'First = 1 and then F <= Cs'Length;

   function No_Functions_Text (Package_Name : String) return String is
     (No_Functions_Prefix & Package_Name)
     with Pre  => Package_Name'Length <= 4_096,
          Post => No_Functions_Text'Result'Length = No_Functions_Prefix'Length + Package_Name'Length;

end Lovelace_Declaration_Merger_Pkg;
