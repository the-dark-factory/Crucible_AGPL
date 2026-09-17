--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2bfa954fe09078f383d3cac0f298826ba5f4852fd962b60b173a2a07306f2053
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
with Model_Reply_Pkg;

package Model_Rail_Call_Pkg with SPARK_Mode => Off is

   Conf_Path : constant String := "config/rail.conf";

   type Text_Access is access String;

   procedure Complete
     (Prompt  : String;
      Text    : out Text_Access;
      Outcome : out Model_Reply_Pkg.Outcome_Kind);

end Model_Rail_Call_Pkg;
