--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5a2b045bdf5cf7ba1619a48b4ca19d7bf21197800b9a2fb584e24d4843ef9078
--
package Fetch_Sign_Pkg with SPARK_Mode is
   --  PURPOSE: the signed fetch, wire version 2. Check says whether six values make a
   --  well-formed signed fetch; Signed_Text is the exact text the sender's enrolled key signs;
   --  Line is the one JSON line the fetch edge sends.
   --  USAGE: the fetch edge measures the network id, its sender id (the enrol record's
   --  fingerprint), its public key file as hex, the current unix minute as decimal digits, the file name and the signature
   --  as hex, asks Check, and builds Line only when Check gives Fetch_Ok.

   Digest_Hex_Length : constant := 64;
   Max_Minute_Digits : constant := 9;
   Max_Name_Length : constant := 128;
   Max_Sig_Hex : constant := 8_192;
   Max_Key_Hex : constant := 2_048;

   function Is_Hex_Char (C : Character) return Boolean is
     (C in '0' .. '9' or else C in 'a' .. 'f')
     with Global => null,
          Post => Is_Hex_Char'Result = (C in '0' .. '9' or else C in 'a' .. 'f');

   function Is_Hex (S : String) return Boolean is
     ((for all I in S'Range => Is_Hex_Char (S (I))))
     with Global => null,
          Post => Is_Hex'Result = (for all I in S'Range => Is_Hex_Char (S (I)));

   function Is_Digest (S : String) return Boolean is
     (S'Length = Digest_Hex_Length and then Is_Hex (S))
     with Global => null,
          Post => Is_Digest'Result = (S'Length = Digest_Hex_Length and then Is_Hex (S));

   function Is_Minute (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= Max_Minute_Digits and then (for all I in S'Range => S (I) in '0' .. '9'))
     with Global => null,
          Post => Is_Minute'Result = (S'Length >= 1 and then S'Length <= Max_Minute_Digits and then (for all I in S'Range => S (I) in '0' .. '9'));

   function Is_Name_Char (C : Character) return Boolean is
     (C in 'a' .. 'z' or else C in '0' .. '9' or else C = '.' or else C = '-' or else C = '_')
     with Global => null,
          Post => Is_Name_Char'Result = (C in 'a' .. 'z' or else C in '0' .. '9' or else C = '.' or else C = '-' or else C = '_');

   function Is_Name (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= Max_Name_Length and then S (S'First) /= '.' and then (for all I in S'Range => Is_Name_Char (S (I))) and then (for all I in S'First .. S'Last - 1 => not (S (I) = '.' and then S (I + 1) = '.')))
     with Global => null,
          Post => Is_Name'Result = (S'Length >= 1 and then S'Length <= Max_Name_Length and then S (S'First) /= '.' and then (for all I in S'Range => Is_Name_Char (S (I))) and then (for all I in S'First .. S'Last - 1 => not (S (I) = '.' and then S (I + 1) = '.')));

   function Is_Sig_Hex (S : String) return Boolean is
     (S'Length >= 2 and then S'Length <= Max_Sig_Hex and then S'Length mod 2 = 0 and then Is_Hex (S))
     with Global => null,
          Post => Is_Sig_Hex'Result = (S'Length >= 2 and then S'Length <= Max_Sig_Hex and then S'Length mod 2 = 0 and then Is_Hex (S));

   function Is_Key_Hex (S : String) return Boolean is
     (S'Length >= 2 and then S'Length <= Max_Key_Hex and then S'Length mod 2 = 0 and then Is_Hex (S))
     with Global => null,
          Post => Is_Key_Hex'Result = (S'Length >= 2 and then S'Length <= Max_Key_Hex and then S'Length mod 2 = 0 and then Is_Hex (S));

   type Fetch_Word is (Fetch_Ok, Bad_Network, Bad_Sender, Bad_Key, Bad_Minute, Bad_Name, Bad_Sig);

   function Check (Network : String; Sender : String; Key_Hex : String; Minute : String; Name : String; Sig_Hex : String) return Fetch_Word is
     ((if not Is_Digest (Network) then Bad_Network elsif not Is_Digest (Sender) then Bad_Sender elsif not Is_Key_Hex (Key_Hex) then Bad_Key elsif not Is_Minute (Minute) then Bad_Minute elsif not Is_Name (Name) then Bad_Name elsif not Is_Sig_Hex (Sig_Hex) then Bad_Sig else Fetch_Ok))
     with Global => null,
          Post => ((Check'Result = Fetch_Ok) = (Is_Digest (Network) and then Is_Digest (Sender) and then Is_Key_Hex (Key_Hex) and then Is_Minute (Minute) and then Is_Name (Name) and then Is_Sig_Hex (Sig_Hex)))
                  and then ((if not Is_Digest (Sender) and then Is_Digest (Network) then Check'Result = Bad_Sender))
                  and then ((if not Is_Name (Name) then Check'Result /= Fetch_Ok));

   Signed_Head : constant String := "df-fetch v2 ";

   function Signed_Text (Network : String; Sender : String; Minute : String; Name : String) return String is
     (Signed_Head & Network & ' ' & Sender & ' ' & Minute & ' ' & Name)
     with Global => null,
          Pre => Is_Digest (Network) and then Is_Digest (Sender) and then Is_Minute (Minute) and then Is_Name (Name);

   Quote : constant Character := Character'Val (34);

   function Field (Name : String; Value : String) return String is
     (Quote & Name & Quote & ':' & Quote & Value & Quote)
     with Global => null,
          Pre => Name'Length <= 16 and then Value'Length <= Max_Sig_Hex,
          Post => Field'Result = (Quote & Name & Quote & ':' & Quote & Value & Quote);

   function Line (Network : String; Sender : String; Key_Hex : String; Minute : String; Name : String; Sig_Hex : String) return String is
     ('{' & Field ("op", "fetch") & ',' & Field ("name", Name) & ',' & Field ("v", "2") & ',' & Field ("network", Network) & ',' & Field ("sender", Sender) & ',' & Field ("key", Key_Hex) & ',' & Field ("minute", Minute) & ',' & Field ("sig", Sig_Hex) & '}')
     with Global => null,
          Pre => Check (Network, Sender, Key_Hex, Minute, Name, Sig_Hex) = Fetch_Ok;

end Fetch_Sign_Pkg;
