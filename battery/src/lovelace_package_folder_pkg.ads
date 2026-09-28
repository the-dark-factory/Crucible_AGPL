--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: bce0c75bcc2432a3c7a1ff1977f638c8b3ccd239adfd851696a3200ff429c8c1
--
with Lovelace_Refusal_Texts_Pkg;
use Lovelace_Refusal_Texts_Pkg;

package Lovelace_Package_Folder_Pkg with SPARK_Mode, Pure is

   Unset : constant Integer := -1;

   subtype Acc_Grade is Integer range -1 .. 2;
   subtype Grade_Value is Integer range -1 .. 2;
   subtype Edge_Digit is Natural range 0 .. 2;

   type Refusal_Kind is (No_Refusal, Fold_Refused, Function_Refused, Nothing_Graded_Refusal, No_Grade_Reached);

   type Roll_Answer is record
      Answered : Boolean    := False;
      Digit    : Edge_Digit := 0;
   end record;

   type Fold_State is record
      Grade       : Acc_Grade    := Unset;
      Graded      : Count        := 0;
      Definitions : Count        := 0;
      Errors      : Count        := 0;
      Refusal     : Refusal_Kind := No_Refusal;
   end record;

   function Initial_State return Fold_State is
     ((Grade => Unset, Graded => 0, Definitions => 0, Errors => 0, Refusal => No_Refusal))
     with Post => Initial_State'Result.Grade = Unset
                  and then Initial_State'Result.Graded = 0
                  and then Initial_State'Result.Refusal = No_Refusal;

   function Needs_Roll (S : Fold_State) return Boolean is
     (S.Grade /= Unset);

   function Roll_In (S : Fold_State; G : Edge_Digit; A : Roll_Answer) return Fold_State is
     (if S.Grade = Unset then (S with delta Grade => G)
      elsif A.Answered then (S with delta Grade => A.Digit)
      else (S with delta Grade => Unset, Refusal => Fold_Refused, Errors => S.Errors + 1))
     with Pre  => S.Errors < Max_Count,
          Post => Roll_In'Result.Graded = S.Graded
                  and then Roll_In'Result.Definitions = S.Definitions
                  and then (if S.Grade = Unset then Roll_In'Result.Grade = G)
                  and then (if S.Grade /= Unset and then A.Answered then Roll_In'Result.Grade = A.Digit)
                  and then (if S.Grade /= Unset and then not A.Answered then
                              (Roll_In'Result.Grade = Unset and then Roll_In'Result.Refusal = Fold_Refused));

   function Count_Definition (S : Fold_State) return Fold_State is
     ((S with delta Definitions => S.Definitions + 1))
     with Pre  => S.Definitions < Max_Count,
          Post => Count_Definition'Result.Definitions = S.Definitions + 1
                  and then Count_Definition'Result.Grade = S.Grade
                  and then Count_Definition'Result.Errors = S.Errors;

   function Count_Graded (S : Fold_State) return Fold_State is
     ((S with delta Graded => S.Graded + 1))
     with Pre  => S.Graded < Max_Count,
          Post => Count_Graded'Result.Graded = S.Graded + 1
                  and then Count_Graded'Result.Grade = S.Grade
                  and then Count_Graded'Result.Errors = S.Errors;

   function On_Definition (S : Fold_State; A : Roll_Answer) return Fold_State is
     (Roll_In (Count_Definition (S), 0, A))
     with Pre  => S.Definitions < Max_Count and then S.Errors < Max_Count,
          Post => On_Definition'Result.Definitions = S.Definitions + 1
                  and then On_Definition'Result.Graded = S.Graded;

   function On_Function (S : Fold_State; G : Grade_Value; A : Roll_Answer) return Fold_State is
     (if G < 0 then (S with delta Grade => Unset, Refusal => Function_Refused)
      else Roll_In (Count_Graded (S), G, A))
     with Pre  => S.Graded < Max_Count and then S.Errors < Max_Count,
          Post => (if G < 0 then
                     (On_Function'Result.Grade = Unset
                      and then On_Function'Result.Refusal = Function_Refused
                      and then On_Function'Result.Graded = S.Graded))
                  and then (if G >= 0 then On_Function'Result.Graded = S.Graded + 1);

   function Final_Refusal (S : Fold_State) return Refusal_Kind is
     (if S.Refusal /= No_Refusal then S.Refusal
      elsif S.Graded = 0 then Nothing_Graded_Refusal
      elsif S.Grade = Unset then No_Grade_Reached
      else No_Refusal)
     with Post => (if S.Graded = 0 then Final_Refusal'Result /= No_Refusal)
                  and then (if Final_Refusal'Result = No_Refusal then S.Grade /= Unset)
                  and then (if S.Refusal /= No_Refusal then Final_Refusal'Result = S.Refusal);

   function Package_Grade (S : Fold_State) return Acc_Grade is
     (if Final_Refusal (S) = No_Refusal then S.Grade else Unset)
     with Post => (if Final_Refusal (S) /= No_Refusal then Package_Grade'Result = Unset)
                  and then (if S.Graded = 0 then Package_Grade'Result = Unset);

   function Refusal_Text (S : Fold_State; Functions_Read : Count) return String is
     (if Final_Refusal (S) = Fold_Refused then Fold_Refused_Text
      elsif Final_Refusal (S) = Function_Refused then Function_Grade_Refused_Text
      elsif Final_Refusal (S) = Nothing_Graded_Refusal then Nothing_Graded (Functions_Read, S.Definitions)
      elsif Final_Refusal (S) = No_Grade_Reached then No_Package_Grade_Text
      else "")
     with Post => ((Refusal_Text'Result'Length = 0) = (Final_Refusal (S) = No_Refusal));

end Lovelace_Package_Folder_Pkg;
