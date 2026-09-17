--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 96a1b8d00d9810faadfb036a8ec5a19f8f901b2db221e1ae9a7e61cd055da2ec
--
package Fill_Route_Pkg with SPARK_Mode is

   type Gate_Kind is (Gate_Accepted, Gate_Assumed_Body, Gate_Contracts_Not_Checked, Gate_Other);

   type Route_Kind is (Route_Fill, Route_Fill_Deferred, Route_Refuse);

   function Classify_Gate (Word : String) return Gate_Kind is
     ((if Word = "accepted" then Gate_Accepted
       elsif Word = "refused-assumed-body" then Gate_Assumed_Body
       elsif Word = "refused-contracts-not-checked" then Gate_Contracts_Not_Checked
       else Gate_Other))
     with Post =>
       (Classify_Gate'Result = Gate_Accepted) = (Word = "accepted") and
       (Classify_Gate'Result = Gate_Assumed_Body) = (Word = "refused-assumed-body") and
       (Classify_Gate'Result = Gate_Contracts_Not_Checked) = (Word = "refused-contracts-not-checked") and
       ((Classify_Gate'Result = Gate_Other) = (Word /= "accepted" and Word /= "refused-assumed-body" and Word /= "refused-contracts-not-checked"));

   function Is_Body_Deferred_Refusal (Kind : Gate_Kind) return Boolean is
     (Kind = Gate_Assumed_Body or Kind = Gate_Contracts_Not_Checked)
     with Post =>
       (Is_Body_Deferred_Refusal'Result = ((Kind = Gate_Assumed_Body) or (Kind = Gate_Contracts_Not_Checked)));

   function Round_Clean (Compile_Errors, Cheat_Markers, Unproved : Natural) return Boolean is
     (Compile_Errors = 0 and Cheat_Markers = 0 and Unproved = 0)
     with Post =>
       (Round_Clean'Result = ((Compile_Errors = 0) and (Cheat_Markers = 0) and (Unproved = 0)));

   function Deferral_Declared (Skipped, Skipped_Undeclared : Natural) return Boolean is
     (Skipped >= 1 and Skipped_Undeclared = 0)
     with Post =>
       ((Deferral_Declared'Result = ((Skipped >= 1) and (Skipped_Undeclared = 0))) and
        ((if Skipped_Undeclared > 0 then not Deferral_Declared'Result)));

   function Decide (Word : String; Compile_Errors, Cheat_Markers, Unproved, Skipped, Skipped_Undeclared : Natural) return Route_Kind is
     ((if Classify_Gate (Word) = Gate_Accepted and Round_Clean (Compile_Errors, Cheat_Markers, Unproved) and Skipped = 0 then Route_Fill
       elsif Is_Body_Deferred_Refusal (Classify_Gate (Word)) and Round_Clean (Compile_Errors, Cheat_Markers, Unproved) and Deferral_Declared (Skipped, Skipped_Undeclared) then Route_Fill_Deferred
       else Route_Refuse))
     with Post =>
       ((Decide'Result = Route_Fill) = (Classify_Gate (Word) = Gate_Accepted and Round_Clean (Compile_Errors, Cheat_Markers, Unproved) and Skipped = 0)) and
       ((Decide'Result = Route_Fill_Deferred) = (Classify_Gate (Word) /= Gate_Accepted and Is_Body_Deferred_Refusal (Classify_Gate (Word)) and Round_Clean (Compile_Errors, Cheat_Markers, Unproved) and Deferral_Declared (Skipped, Skipped_Undeclared))) and
       ((if Classify_Gate (Word) = Gate_Other then Decide'Result = Route_Refuse)) and
       ((if not Round_Clean (Compile_Errors, Cheat_Markers, Unproved) then Decide'Result = Route_Refuse)) and
       ((if Skipped_Undeclared > 0 then Decide'Result /= Route_Fill_Deferred)) and
       ((if Decide'Result /= Route_Refuse then Compile_Errors = 0 and Cheat_Markers = 0 and Unproved = 0));

end Fill_Route_Pkg;
