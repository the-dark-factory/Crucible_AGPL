--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: af70a26bfa56efccc9ba01a29c3f5077c3df62c793f34ad45995f6fb4e1b77d7
--
with Lovelace_Message_Rules_Pkg;
with Lovelace_Outcome_Rules_Pkg;
with Lovelace_Word_Rules_Pkg;
with Lovelace_Rte_Stage_Pkg;

package Lovelace_T4_Stage_Pkg with SPARK_Mode, Pure is

   package MR renames Lovelace_Message_Rules_Pkg;
   package OR_Rules renames Lovelace_Outcome_Rules_Pkg;
   package WR renames Lovelace_Word_Rules_Pkg;
   package RS renames Lovelace_Rte_Stage_Pkg;

   function Never_Asserted (Is_Boolean : Boolean; Has_Post : Boolean;
                            Name : String; Contracts : String) return Boolean is
     (Is_Boolean and then not Has_Post and then not WR.Contains_Name (Contracts, Name, False))
     with Pre => Contracts'First = 1 and then Contracts'Length <= WR.Max_Text
                 and then WR.Is_Word_Form (Name);

   function T4_Facts_Of (Base_Reached : Boolean; Msgs : MR.Message_Array; Count : Natural;
                         S : RS.Line_Span; Never : Boolean) return OR_Rules.T4_Facts is
     ((Base_Reached    => Base_Reached,
       Unused_In_Range => MR.Unused_In (Msgs, Count, S.From, S.To),
       Never_Asserted  => Never))
     with Pre  => Msgs'First = 1 and then Count <= Msgs'Last,
          Post => T4_Facts_Of'Result.Base_Reached = Base_Reached
                  and then T4_Facts_Of'Result.Never_Asserted = Never;

   function T4_For (Base_Reached : Boolean; Msgs : MR.Message_Array; Count : Natural;
                    S : RS.Line_Span; Never : Boolean) return OR_Rules.Outcome is
     (OR_Rules.T4_Of (T4_Facts_Of (Base_Reached, Msgs, Count, S, Never)))
     with Pre  => Msgs'First = 1 and then Count <= Msgs'Last,
          Post => ((T4_For'Result = OR_Rules.Unreached) = (not Base_Reached))
                  and then (if Base_Reached and then Never then T4_For'Result = OR_Rules.Proved)
                  and then T4_For'Result /= OR_Rules.Inapplicable;

end Lovelace_T4_Stage_Pkg;
