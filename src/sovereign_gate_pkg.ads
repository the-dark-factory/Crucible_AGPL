--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: ddf314332d9139586fe3c43465bd51bc0e8e81401d3d118c42683eff59bd8c98
--
package Sovereign_Gate_Pkg with SPARK_Mode, Pure is

   Max_Endpoint : constant := 1024;

   Prefix_Loopback : constant String := "http://127.0.0.1";
   Prefix_Localhost : constant String := "http://localhost";

   type Route_Kind is (On_Estate, Off_Estate, Refused_Sovereign_Off_Estate);

   function Starts_With (Endpoint : String; Prefix : String) return Boolean
     is ((Endpoint'Length >= Prefix'Length
          and then Endpoint (Endpoint'First .. Endpoint'First + Prefix'Length - 1) = Prefix))
     with Global => null,
          Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint
                and then Prefix'First = 1 and then Prefix'Length >= 1
                and then Prefix'Length <= 64;

   function Endpoint_On_Estate (Endpoint : String) return Boolean
     is ((Starts_With (Endpoint, Prefix_Loopback)
          or else Starts_With (Endpoint, Prefix_Localhost)))
     with Global => null,
          Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint;

   function Route_Of (Endpoint : String; Sovereign : Boolean) return Route_Kind
     is ((if Endpoint_On_Estate (Endpoint) then On_Estate
          elsif Sovereign then Refused_Sovereign_Off_Estate
          else Off_Estate))
     with Global => null,
          Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
          Post => (Route_Of'Result = Off_Estate) = (not Sovereign and then not Endpoint_On_Estate (Endpoint))
                  and then (Route_Of'Result = Refused_Sovereign_Off_Estate) = (Sovereign and then not Endpoint_On_Estate (Endpoint))
                  and then (Route_Of'Result = On_Estate) = Endpoint_On_Estate (Endpoint);

   function Leaves_Estate (Endpoint : String; Sovereign : Boolean) return Boolean
     is ((Route_Of (Endpoint, Sovereign) = Off_Estate))
     with Global => null,
          Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
          Post => (if Leaves_Estate'Result then not Sovereign);

end Sovereign_Gate_Pkg;
