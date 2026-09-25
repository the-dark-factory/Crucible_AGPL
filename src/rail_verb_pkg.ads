--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 491e284042263f28bb10cf6c8365f82db712c86b0ad1bbb541b8db1dadd4b08e
--
package Rail_Verb_Pkg with SPARK_Mode is
   --  PURPOSE. The decision behind CRUCIBLE's rail.set door verb. An operator may reassign WHICH model line
   --  already declared in rail.conf serves a tier (standard or elevated) -- and nothing else. Asking to write
   --  host, port, sovereign or any other estate fact is refused in words: the estate boundary stays a fact only
   --  someone at the machine can move (Tony, 2026-09-25). The door measures the facts; this package decides.
   --  USAGE. The door fills a Facts record from the request and the proven judges of rail.conf, calls Decide,
   --  and acts ONLY on Set_Swap (swap the tiers of the two declared model lines) or Set_Unchanged (write
   --  nothing). Every other verdict is a refusal, and Word_Of names it.

   type Tier_Request is (Want_Standard, Want_Elevated, Want_Unknown);

   type Facts_Type is record
      forbidden_key     : Boolean;   --  the arguments name host, port, sovereign, rail, protocol, timeout_seconds,
                                     --  max_reply_bytes or max_tokens
      tier_given        : Boolean;   --  the arguments carry a tier string
      model_given       : Boolean;   --  the arguments carry a model string
      requested         : Tier_Request;
      conf_ok           : Boolean;   --  the whole rail.conf's tier verdict is select_ok
      target_found      : Boolean;   --  a declared model line names exactly that model
      target_serves     : Boolean;   --  that line already serves the requested tier
      other_line_exists : Boolean;   --  a second declared model line exists (the one it would swap with)
   end record;

   type Verdict_Type is (Set_Swap, Set_Unchanged, Refused_Estate_Boundary, Refused_Missing_Argument,
                         Refused_Unknown_Tier, Refused_Conf_Not_Ok, Refused_Not_Declared, Refused_No_Other_Line);

   Set_Swap_Word                 : constant String := "set_swap";
   Set_Unchanged_Word            : constant String := "set_unchanged";
   Refused_Estate_Boundary_Word  : constant String := "refused_estate_boundary";
   Refused_Missing_Argument_Word : constant String := "refused_missing_argument";
   Refused_Unknown_Tier_Word     : constant String := "refused_unknown_tier";
   Refused_Conf_Not_Ok_Word      : constant String := "refused_conf_not_ok";
   Refused_Not_Declared_Word     : constant String := "refused_not_declared";
   Refused_No_Other_Line_Word    : constant String := "refused_no_other_line";

   function Writable_Keys_Are_Model_And_Tier (F : Facts_Type) return Boolean is
     ((not F.forbidden_key))
   with Post => ((if Writable_Keys_Are_Model_And_Tier'Result then not F.forbidden_key) and then
                 (if not F.forbidden_key then Writable_Keys_Are_Model_And_Tier'Result));

   function Decide (F : Facts_Type) return Verdict_Type is
     ((if not Writable_Keys_Are_Model_And_Tier (F) then Refused_Estate_Boundary
       elsif not F.tier_given or else not F.model_given then Refused_Missing_Argument
       elsif F.requested = Want_Unknown then Refused_Unknown_Tier
       elsif not F.conf_ok then Refused_Conf_Not_Ok
       elsif not F.target_found then Refused_Not_Declared
       elsif F.target_serves then Set_Unchanged
       elsif not F.other_line_exists then Refused_No_Other_Line
       else Set_Swap))
   with Post => ((if F.forbidden_key then (Decide'Result = Refused_Estate_Boundary)) and then
                 (if not F.forbidden_key and then (not F.tier_given or else not F.model_given) then (Decide'Result = Refused_Missing_Argument)) and then
                 (if not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested = Want_Unknown) then (Decide'Result = Refused_Unknown_Tier)) and then
                 (if not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested /= Want_Unknown) and then not F.conf_ok then (Decide'Result = Refused_Conf_Not_Ok)) and then
                 (if not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested /= Want_Unknown) and then F.conf_ok and then not F.target_found then (Decide'Result = Refused_Not_Declared)) and then
                 (if not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested /= Want_Unknown) and then F.conf_ok and then F.target_found and then F.target_serves then (Decide'Result = Set_Unchanged)) and then
                 (if not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested /= Want_Unknown) and then F.conf_ok and then F.target_found and then not F.target_serves and then not F.other_line_exists then (Decide'Result = Refused_No_Other_Line)) and then
                 (if not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested /= Want_Unknown) and then F.conf_ok and then F.target_found and then not F.target_serves and then F.other_line_exists then (Decide'Result = Set_Swap)) and then
                 (if (Decide'Result = Set_Swap) or else (Decide'Result = Set_Unchanged) then not F.forbidden_key and then F.tier_given and then F.model_given and then (F.requested /= Want_Unknown) and then F.conf_ok and then F.target_found));

   function Word_Of (V : Verdict_Type) return String is
     (case V is
        when Set_Swap => Set_Swap_Word,
        when Set_Unchanged => Set_Unchanged_Word,
        when Refused_Estate_Boundary => Refused_Estate_Boundary_Word,
        when Refused_Missing_Argument => Refused_Missing_Argument_Word,
        when Refused_Unknown_Tier => Refused_Unknown_Tier_Word,
        when Refused_Conf_Not_Ok => Refused_Conf_Not_Ok_Word,
        when Refused_Not_Declared => Refused_Not_Declared_Word,
        when Refused_No_Other_Line => Refused_No_Other_Line_Word)
   with Post => ((if (V = Set_Swap) then Word_Of'Result = Set_Swap_Word) and then
                 (if (V = Set_Unchanged) then Word_Of'Result = Set_Unchanged_Word) and then
                 (if (V = Refused_Estate_Boundary) then Word_Of'Result = Refused_Estate_Boundary_Word) and then
                 (if (V = Refused_Missing_Argument) then Word_Of'Result = Refused_Missing_Argument_Word) and then
                 (if (V = Refused_Unknown_Tier) then Word_Of'Result = Refused_Unknown_Tier_Word) and then
                 (if (V = Refused_Conf_Not_Ok) then Word_Of'Result = Refused_Conf_Not_Ok_Word) and then
                 (if (V = Refused_Not_Declared) then Word_Of'Result = Refused_Not_Declared_Word) and then
                 (if (V = Refused_No_Other_Line) then Word_Of'Result = Refused_No_Other_Line_Word));

end Rail_Verb_Pkg;
