--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 61094602ea85b322d80e2f73816f0a79a745c2194710dd55c843dd4fa224f0e3
--
package Round_Progress_Pkg with SPARK_Mode is
   --  PURPOSE: has an Emit_Contract repair round made progress? A round whose unit is
   --  byte-identical to the previous round's unit repeated it: the model ignored the
   --  compiler's lines, and every further round on the same prompt is wasted.
   --  USAGE: the Emit_Contract edge keeps the previous round's unit and asks Repeated
   --  before it starts the next round; a repeat stops the stage, refused by name.

   Max_Unit : constant := 262_144;

   function Repeated (Prev_Unit : String; This_Unit : String) return Boolean is
     (Prev_Unit'Length > 0 and then This_Unit = Prev_Unit)
     with Global => null,
          Pre  => Prev_Unit'Length <= Max_Unit and then This_Unit'Length <= Max_Unit,
          Post => Repeated'Result = (Prev_Unit'Length > 0 and then This_Unit = Prev_Unit)
                  and then (if Prev_Unit'Length = 0 then not Repeated'Result)
                  and then (if Repeated'Result then This_Unit'Length = Prev_Unit'Length);

   function May_Continue (Prev_Unit : String; This_Unit : String) return Boolean is
     (not Repeated (Prev_Unit, This_Unit))
     with Global => null,
          Pre  => Prev_Unit'Length <= Max_Unit and then This_Unit'Length <= Max_Unit,
          Post => May_Continue'Result = (not Repeated (Prev_Unit, This_Unit))
                  and then (if Prev_Unit'Length = 0 then May_Continue'Result);

end Round_Progress_Pkg;
