--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: aaa75c60e656095f3cb8d830f8236632d994167108011273c9741001339acde5
--
package Reef_Key_Claim_Pkg with SPARK_Mode is

   subtype Digest_Text is String (1 .. 64);

   function Is_Digest (S : Digest_Text) return Boolean is
     (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f')
   with Post => Is_Digest'Result = (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f');

   type Role_Kind is (Role_Sender, Role_Solver);

   type Key_Record is record
      Key_Fingerprint : Digest_Text;
      Factory_Id      : Digest_Text;
      Nonce_Echo      : Digest_Text;
      Role            : Role_Kind;
      Issued_At       : Natural;
      Expires_At      : Natural;
      Reef_Signed     : Boolean;
      Revoked         : Boolean;
      CLA_Signed      : Boolean;
   end record;

   type Request is record
      Factory_Id : Digest_Text;
      Nonce      : Digest_Text;
      Now        : Natural;
   end record;

   function Accept_Key (K : Key_Record; R : Request) return Boolean is
     (Is_Digest (K.Key_Fingerprint)
      and then Is_Digest (K.Factory_Id)
      and then Is_Digest (K.Nonce_Echo)
      and then Is_Digest (R.Factory_Id)
      and then Is_Digest (R.Nonce)
      and then K.Reef_Signed
      and then not K.Revoked
      and then K.Factory_Id = R.Factory_Id
      and then K.Nonce_Echo = R.Nonce
      and then K.Issued_At <= R.Now
      and then R.Now < K.Expires_At
      and then (K.Role = Role_Sender or else K.CLA_Signed))
   with Post => Accept_Key'Result = (Is_Digest (K.Key_Fingerprint)
      and then Is_Digest (K.Factory_Id)
      and then Is_Digest (K.Nonce_Echo)
      and then Is_Digest (R.Factory_Id)
      and then Is_Digest (R.Nonce)
      and then K.Reef_Signed
      and then not K.Revoked
      and then K.Factory_Id = R.Factory_Id
      and then K.Nonce_Echo = R.Nonce
      and then K.Issued_At <= R.Now
      and then R.Now < K.Expires_At
      and then (K.Role = Role_Sender or else K.CLA_Signed));

   function Is_Live (K : Key_Record; Now : Natural) return Boolean is
     (K.Reef_Signed and then not K.Revoked and then K.Issued_At <= Now and then Now < K.Expires_At)
   with Post => Is_Live'Result = (K.Reef_Signed and then not K.Revoked and then K.Issued_At <= Now and then Now < K.Expires_At);

   function May_Send (K : Key_Record; Now : Natural) return Boolean is
     (K.Reef_Signed and then not K.Revoked and then K.Issued_At <= Now and then Now < K.Expires_At)
   with Post => May_Send'Result = (K.Reef_Signed and then not K.Revoked and then K.Issued_At <= Now and then Now < K.Expires_At);

   function May_Solve (K : Key_Record; Now : Natural) return Boolean is
     (K.Reef_Signed and then not K.Revoked and then K.Issued_At <= Now and then Now < K.Expires_At and then K.Role = Role_Solver and then K.CLA_Signed)
   with Post => May_Solve'Result = (K.Reef_Signed and then not K.Revoked and then K.Issued_At <= Now and then Now < K.Expires_At and then K.Role = Role_Solver and then K.CLA_Signed);

end Reef_Key_Claim_Pkg;
