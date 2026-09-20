--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 593683a232a2d6687ec53d50ceddffac6b6a7cf8e6ff3e284c54917e5a45ccce
--
package Sovereign_Gate_Pkg with SPARK_Mode, Pure is

   Max_Endpoint : constant := 1024;

   Prefix_Length : constant := 16;

   subtype Prefix_String is String (1 .. Prefix_Length);

   Prefix_Loopback  : constant Prefix_String := "http://127.0.0.1";
   Prefix_Localhost : constant Prefix_String := "http://localhost";

   Colon   : constant Character := ':';
   Slash   : constant Character := '/';
   At_Sign : constant Character := '@';
   Percent : constant Character := '%';

   type Route_Kind is (On_Estate, Off_Estate, Refused_Sovereign_Off_Estate);

   function Authority_Is_Plain (Endpoint : String) return Boolean
   is ((for all I in Endpoint'First .. Endpoint'Last =>
          Endpoint (I) /= At_Sign and then Endpoint (I) /= Percent))
   with Global => null,
        Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
        Post => Authority_Is_Plain'Result =
                  (not (for some I in Endpoint'First .. Endpoint'Last =>
                           Endpoint (I) = At_Sign or else Endpoint (I) = Percent));

   function Starts_With (Endpoint : String; Prefix : Prefix_String) return Boolean
   is (Endpoint'Length >= Prefix_Length and then
        Endpoint (Endpoint'First .. Endpoint'First + Prefix_Length - 1) = Prefix)
   with Global => null,
        Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
        Post => Starts_With'Result =
                  (Endpoint'Length >= Prefix_Length and then
                     (for all I in 1 .. Prefix_Length =>
                        Endpoint (Endpoint'First + I - 1) = Prefix (I)));

   function Host_Ends_Here (Endpoint : String) return Boolean
   is (Endpoint'Length = Prefix_Length
       or else Endpoint (Endpoint'First + Prefix_Length) = Colon
       or else Endpoint (Endpoint'First + Prefix_Length) = Slash)
   with Global => null,
        Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint
              and then Endpoint'Length >= Prefix_Length,
        Post => Host_Ends_Here'Result =
                  (if Endpoint'Length > Prefix_Length
                   then (Endpoint (Endpoint'First + Prefix_Length) = Colon
                         or else Endpoint (Endpoint'First + Prefix_Length) = Slash)
                   else True);

   function Endpoint_On_Estate (Endpoint : String) return Boolean
   is (Authority_Is_Plain (Endpoint)
       and then (Starts_With (Endpoint, Prefix_Loopback)
                 or else Starts_With (Endpoint, Prefix_Localhost))
       and then Host_Ends_Here (Endpoint))
   with Global => null,
        Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
        Post => Endpoint_On_Estate'Result =
                  (Endpoint'Length >= Prefix_Length
                   and then (Endpoint (Endpoint'First .. Endpoint'First + Prefix_Length - 1) = Prefix_Loopback
                             or else Endpoint (Endpoint'First .. Endpoint'First + Prefix_Length - 1) = Prefix_Localhost)
                   and then (Endpoint'Length = Prefix_Length
                             or else Endpoint (Endpoint'First + Prefix_Length) = Colon
                             or else Endpoint (Endpoint'First + Prefix_Length) = Slash)
                   and then Authority_Is_Plain (Endpoint));

   function Route_Of (Endpoint : String; Sovereign : Boolean) return Route_Kind
   is ((if Endpoint_On_Estate (Endpoint) then On_Estate
        elsif Sovereign then Refused_Sovereign_Off_Estate
        else Off_Estate))
   with Global => null,
        Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
        Post => ((Route_Of'Result = Off_Estate) = (not Sovereign and then not Endpoint_On_Estate (Endpoint)))
                and then ((Route_Of'Result = Refused_Sovereign_Off_Estate) = (Sovereign and then not Endpoint_On_Estate (Endpoint)))
                and then ((Route_Of'Result = On_Estate) = Endpoint_On_Estate (Endpoint));

   function Leaves_Estate (Endpoint : String; Sovereign : Boolean) return Boolean
   is (Route_Of (Endpoint, Sovereign) = Off_Estate)
   with Global => null,
        Pre => Endpoint'First = 1 and then Endpoint'Length <= Max_Endpoint,
        Post => Leaves_Estate'Result = (not Sovereign and then not Endpoint_On_Estate (Endpoint));

end Sovereign_Gate_Pkg;
