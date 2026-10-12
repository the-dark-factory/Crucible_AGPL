--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 536ed07043fa3c7e5296f4e916d0ca83015c35cba13f737eacdb8f0e46c0e7ce
--
package Reef_Enrol_Record_Pkg with SPARK_Mode is
  --  PURPOSE: the shape half of Reef enrolment. Checks each enrolment field against its exact
  --  shape, refuses an out-of-shape record or enrol_start request with ONE named word in a fixed
  --  order, and builds the one canonical record line the Reef signs. Sender-only: the role field
  --  admits the word sender and nothing else. Nothing defaults; no I/O, no clock, no signing.
  --  USAGE: the Reef's enrol handler asks Request_Refusal about an enrol_start request and its
  --  minted user code, and answers that word when it is not None. At grant it asks Record_Refusal
  --  about the eight record fields and calls Shape_Record only when that is None; it signs the
  --  result followed by one line feed. Trust is decided elsewhere: Reef_Grant_Pkg grants, and the
  --  factory's Reef_Key_Claim_Pkg judges the signed record when it comes back.

   Hex_Length : constant := 64;
   Max_Codename : constant := 32;
   User_Code_Length : constant := 8;
   Max_Unix_Digits : constant := 10;
   Max_Key : constant := 16;
   Max_Record_Length : constant := 376;

   Quote : constant Character := Character'Val (34);
   Colon : constant Character := Character'Val (58);
   Comma : constant Character := Character'Val (44);
   Open_Brace : constant Character := Character'Val (123);
   Close_Brace : constant Character := Character'Val (125);

   Sender_Word : constant String := "sender";
   Cla_True : constant String := "true";
   Cla_False : constant String := "false";
   Max_Unix_Text : constant String := "2147483647";
   Key_Fingerprint : constant String := "fingerprint";
   Key_Factory_Id : constant String := "factory_id";
   Key_Nonce_Echo : constant String := "nonce_echo";
   Key_Role : constant String := "role";
   Key_Issued_At : constant String := "issued_at";
   Key_Expires_At : constant String := "expires_at";
   Key_Cla_Signed : constant String := "cla_signed";
   Key_Codename : constant String := "codename";

   type Refusal is (None, Not_Hex, Bad_Role, Bad_Codename, Bad_Time, Expires_Not_After_Issued, Bad_Cla, Bad_User_Code, Bad_Line_Shape);

   function Is_Hex64 (S : String) return Boolean is
     (S'Length = Hex_Length and then (for all I in S'Range => (S (I) in '0' .. '9' or else S (I) in 'a' .. 'f')))
     with Global => null;

   function Is_Role (S : String) return Boolean is
     (S = Sender_Word)
     with Global => null;

   function Is_Cla (S : String) return Boolean is
     (S = Cla_True or else S = Cla_False)
     with Global => null;

   function Is_Codename (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= Max_Codename and then (for all I in S'Range => (S (I) in 'A' .. 'Z' or else S (I) in 'a' .. 'z' or else S (I) in '0' .. '9' or else S (I) = '_' or else S (I) = '-')))
     with Global => null;

   function Is_User_Code (S : String) return Boolean is
     (S'Length = User_Code_Length and then (for all I in S'Range => (S (I) in 'A' .. 'Z' or else S (I) in '0' .. '9')))
     with Global => null;

   function Is_Unixtime (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= Max_Unix_Digits and then (for all I in S'Range => S (I) in '0' .. '9') and then (if S'Length = 1 then True else S (S'First) /= '0') and then (S'Length < Max_Unix_Digits or else S <= Max_Unix_Text))
     with Global => null;

   function Hexes_Ok (A : String; B : String; C : String) return Boolean is
     (Is_Hex64 (A) and then Is_Hex64 (B) and then Is_Hex64 (C))
     with Global => null;

   function Times_Ok (Issued_At : String; Expires_At : String) return Boolean is
     (Is_Unixtime (Issued_At) and then Is_Unixtime (Expires_At))
     with Global => null;

   function Later_Than (Expires : String; Issued : String) return Boolean is
     ((if Expires'Length /= Issued'Length then Expires'Length > Issued'Length else Expires > Issued))
     with Pre => Is_Unixtime (Expires) and then Is_Unixtime (Issued), Global => null;

   function Fields_In_Shape (Fingerprint : String; Factory_Id : String; Nonce_Echo : String; Role : String; Issued_At : String; Expires_At : String; Cla_Signed : String; Codename : String) return Boolean is
     (Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) and then Is_Role (Role) and then Is_Codename (Codename) and then Times_Ok (Issued_At, Expires_At) and then Later_Than (Expires_At, Issued_At) and then Is_Cla (Cla_Signed))
     with Global => null;

   function Request_In_Shape (Fingerprint : String; Factory_Id : String; Nonce : String; Codename : String; User_Code : String) return Boolean is
     (Hexes_Ok (Fingerprint, Factory_Id, Nonce) and then Is_Codename (Codename) and then Is_User_Code (User_Code))
     with Global => null;

   function Record_Refusal (Fingerprint : String; Factory_Id : String; Nonce_Echo : String; Role : String; Issued_At : String; Expires_At : String; Cla_Signed : String; Codename : String) return Refusal is
     ((if not Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) then Not_Hex elsif not Is_Role (Role) then Bad_Role elsif not Is_Codename (Codename) then Bad_Codename elsif not Times_Ok (Issued_At, Expires_At) then Bad_Time elsif not Later_Than (Expires_At, Issued_At) then Expires_Not_After_Issued elsif not Is_Cla (Cla_Signed) then Bad_Cla else None))
     with Post => (Record_Refusal'Result = None) = Fields_In_Shape (Fingerprint, Factory_Id, Nonce_Echo, Role, Issued_At, Expires_At, Cla_Signed, Codename) and then (if not Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) then Record_Refusal'Result = Not_Hex) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) and then not Is_Role (Role) then Record_Refusal'Result = Bad_Role) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) and then Is_Role (Role) and then not Is_Codename (Codename) then Record_Refusal'Result = Bad_Codename) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) and then Is_Role (Role) and then Is_Codename (Codename) and then not Times_Ok (Issued_At, Expires_At) then Record_Refusal'Result = Bad_Time) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) and then Is_Role (Role) and then Is_Codename (Codename) and then Times_Ok (Issued_At, Expires_At) and then not Later_Than (Expires_At, Issued_At) then Record_Refusal'Result = Expires_Not_After_Issued) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce_Echo) and then Is_Role (Role) and then Is_Codename (Codename) and then Times_Ok (Issued_At, Expires_At) and then Later_Than (Expires_At, Issued_At) and then not Is_Cla (Cla_Signed) then Record_Refusal'Result = Bad_Cla), Global => null;

   function Request_Refusal (Fingerprint : String; Factory_Id : String; Nonce : String; Codename : String; User_Code : String) return Refusal is
     ((if not Hexes_Ok (Fingerprint, Factory_Id, Nonce) then Not_Hex elsif not Is_Codename (Codename) then Bad_Codename elsif not Is_User_Code (User_Code) then Bad_User_Code else None))
     with Post => (Request_Refusal'Result = None) = Request_In_Shape (Fingerprint, Factory_Id, Nonce, Codename, User_Code) and then (if not Hexes_Ok (Fingerprint, Factory_Id, Nonce) then Request_Refusal'Result = Not_Hex) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce) and then not Is_Codename (Codename) then Request_Refusal'Result = Bad_Codename) and then (if Hexes_Ok (Fingerprint, Factory_Id, Nonce) and then Is_Codename (Codename) and then not Is_User_Code (User_Code) then Request_Refusal'Result = Bad_User_Code), Global => null;

   function Member (Key : String; Text : String) return String is
     (Quote & Key & Quote & Colon & Quote & Text & Quote)
     with Pre => Key'Length <= Max_Key and then Text'Length <= Hex_Length, Post => Member'Result = Quote & Key & Quote & Colon & Quote & Text & Quote and then Member'Result'Length = Key'Length + Text'Length + 5, Global => null;

   function Shape_Record (Fingerprint : String; Factory_Id : String; Nonce_Echo : String; Role : String; Issued_At : String; Expires_At : String; Cla_Signed : String; Codename : String) return String is
     (Open_Brace & Member (Key_Fingerprint, Fingerprint) & Comma & Member (Key_Factory_Id, Factory_Id) & Comma & Member (Key_Nonce_Echo, Nonce_Echo) & Comma & Member (Key_Role, Role) & Comma & Member (Key_Issued_At, Issued_At) & Comma & Member (Key_Expires_At, Expires_At) & Comma & Member (Key_Cla_Signed, Cla_Signed) & Comma & Member (Key_Codename, Codename) & Close_Brace)
     with Pre => Fields_In_Shape (Fingerprint, Factory_Id, Nonce_Echo, Role, Issued_At, Expires_At, Cla_Signed, Codename), Post => Shape_Record'Result'Length <= Max_Record_Length, Global => null;

end Reef_Enrol_Record_Pkg;
