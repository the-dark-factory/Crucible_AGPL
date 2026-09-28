--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2ab09b4d9cf29790ea09b404d9d2867b499a4c22110ee2180aa22e75db20681c
--
--  Model_Rail_Call_Pkg -- CRUCIBLE's path to a language model over the MODEL RAIL (step 5 unit 5).
--  Purpose: gather the facts for one completion request and its reply, and let the proven deciders judge them.
--  It decides nothing: the rail line is judged by Rail_Config_Pkg and Model_Rail_Fields_Pkg, the endpoint by
--  Sovereign_Gate_Pkg (a sovereign rail never leaves the estate), the prompt is encoded by Json_String_Pkg.Encode and
--  framed by Model_Request_Pkg, the HTTP reply judged by Http_Reply_Pkg, completeness by Model_Reply_Pkg, and the
--  outcome by Model_Reply_Pkg.Decide. No socket is opened unless the request may be sent. The one socket is
--  Rail_Socket_Edge.Exchange.
--  Configuration: config/rail.conf; the first line valid for BOTH Rail_Config_Pkg (rail "model") and
--  Model_Rail_Fields_Pkg is used.
--  Usage:
--     Model_Rail_Call_Pkg.Complete (Prompt => P, Text => T, Outcome => O);
--     Model_Reply_Pkg.Is_Text (O) is the ONLY case in which T.all is the model's text; otherwise T is null.
with Ada.Strings.Unbounded;
with Model_Reply_Pkg;

package Model_Rail_Call_Pkg with SPARK_Mode => Off is

   Conf_Path : constant String := "config/rail.conf";

   type Text_Access is access String;

   procedure Complete
     (Prompt  : String;
      Text    : out Text_Access;
      Outcome : out Model_Reply_Pkg.Outcome_Kind);

   --  Lineage 6 (2026-09-28, Tony: refusals name the real fault, A11): the same call, and Refusal names why a request was
   --  refused BEFORE it was sent when the operator can fix it -- today only
   --  "prompt_exceeds_context (estimated E tokens > budget B = num_ctx N - max_tokens M)". Otherwise Refusal is empty.
   --  The three-parameter Complete is this call with the Refusal dropped.
   procedure Complete
     (Prompt  : String;
      Text    : out Text_Access;
      Outcome : out Model_Reply_Pkg.Outcome_Kind;
      Refusal : out Ada.Strings.Unbounded.Unbounded_String);

end Model_Rail_Call_Pkg;
