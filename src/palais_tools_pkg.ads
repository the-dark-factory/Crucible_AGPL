--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 065745c032ef5c75e162f0afe62f6dd2f607a60a8e3a5a717440c6801d545946
--
package Palais_Tools_Pkg with SPARK_Mode is

   Enrol_Name   : constant String := """name"":""palais.enrol""";
   Shelf_Name   : constant String := """name"":""palais.shelf""";
   Claim_Name   : constant String := """name"":""palais.claim""";
   Fetch_Name   : constant String := """name"":""palais.fetch""";
   Attempt_Name : constant String := """name"":""palais.attempt""";
   Submit_Name  : constant String := """name"":""palais.submit""";

   Enrol_Desc   : constant String := """description"":""enrol this factory with the Reef under a codename; returns a code for a human to approve at thereef.ink, then keeps the Reef's signed key record; the private key never leaves this factory""";
   Shelf_Desc   : constant String := """description"":""list the unsolved shelf: each entry's digest, its vector and whether it is claimable""";
   Claim_Desc   : constant String := """description"":""take an exclusive lease on one entry; refused without an enrolled key, when another account holds it, or at your claim cap""";
   Fetch_Desc   : constant String := """description"":""read the dossier of an entry you hold the lease on; it carries what the factory measured, never a path, a hostname or the customer's own words""";
   Attempt_Desc : constant String := """description"":""prove a candidate fix LOCALLY on your own prover rail; nothing is sent and nothing is recorded""";
   Submit_Desc  : constant String := """description"":""send a candidate fix for the Palais to prove on its own bench; returns a receipt OF RECEIPT, never a verdict""";

   Enrol_Schema   : constant String := """inputSchema"":{""type"":""object"",""properties"":{""codename"":{""type"":""string""}}}";
   Shelf_Schema   : constant String := """inputSchema"":{""type"":""object"",""properties"":{}}";
   Claim_Schema   : constant String := """inputSchema"":{""type"":""object"",""properties"":{""digest"":{""type"":""string""}}}";
   Fetch_Schema   : constant String := """inputSchema"":{""type"":""object"",""properties"":{""digest"":{""type"":""string""}}}";
   Attempt_Schema : constant String := """inputSchema"":{""type"":""object"",""properties"":{""digest"":{""type"":""string""},""body"":{""type"":""string""}}}";
   Submit_Schema  : constant String := """inputSchema"":{""type"":""object"",""properties"":{""digest"":{""type"":""string""},""body"":{""type"":""string""}}}";

   Enrol_Tool   : constant String := "{" & Enrol_Name & "," & Enrol_Desc & "," & Enrol_Schema & "}";
   Shelf_Tool   : constant String := "{" & Shelf_Name & "," & Shelf_Desc & "," & Shelf_Schema & "}";
   Claim_Tool   : constant String := "{" & Claim_Name & "," & Claim_Desc & "," & Claim_Schema & "}";
   Fetch_Tool   : constant String := "{" & Fetch_Name & "," & Fetch_Desc & "," & Fetch_Schema & "}";
   Attempt_Tool : constant String := "{" & Attempt_Name & "," & Attempt_Desc & "," & Attempt_Schema & "}";
   Submit_Tool  : constant String := "{" & Submit_Name & "," & Submit_Desc & "," & Submit_Schema & "}";

   First_Three  : constant String := Enrol_Tool & "," & Shelf_Tool & "," & Claim_Tool;
   Last_Three   : constant String := Fetch_Tool & "," & Attempt_Tool & "," & Submit_Tool;
   Palais_Tools : constant String := First_Three & "," & Last_Three;

   function Within_Reply_Bound return Boolean is (Palais_Tools'Length <= 4096)
     with Post => (Within_Reply_Bound'Result = (Palais_Tools'Length <= 4096));

end Palais_Tools_Pkg;
