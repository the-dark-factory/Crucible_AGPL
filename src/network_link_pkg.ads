--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8b0623f4a7e448c5b06d1410577462cca92db6d00c0012ffe6b59be2be6ef6ef
--
with Reef_Enrol_Record_Pkg;

package Network_Link_Pkg
  with SPARK_Mode
is
   --  PURPOSE: the network-link judge. A pin of 64 zero digits is no network. A link is established only from an
   --  enrolment record that names this install, verified under the pinned signer, sender role, in date and cleared
   --  of revocation; otherwise Link_Refusal names ONE reason in a fixed order. No I/O, no clock, no signature check.
   --  USAGE: an edge measures the eleven link facts (the pin compiled into the build, the sha256 of the signers line it
   --  verified under, whether state/reef-key.json was read and its signature verified, the record's fingerprint and
   --  this install's own, the record's role and times, the clock as decimal text, the Reef's revocation answer) and
   --  asks Link_Established; on false it records Link_Refusal. Same_Network compares two network ids.

   type Revocation_State is (Rev_Clear, Rev_Revoked, Rev_Unknown);

   type Reason_Kind is (None, No_Network, No_Record, Unverified, Other_Network, Another_Install, Not_Sender, Not_In_Date, Revoked, Revocation_Unknown);

   function Is_Zero_Pin (S : String) return Boolean is
     (S'Length = Reef_Enrol_Record_Pkg.Hex_Length and then
      (for all I in S'Range => S (I) = '0'))
     with Global => null;

   function Is_Network_Id (S : String) return Boolean is
     (Reef_Enrol_Record_Pkg.Is_Hex64 (S) and then not Is_Zero_Pin (S))
     with Global => null;

   function Same_Network (A, B : String) return Boolean is
     (Is_Network_Id (A) and then Is_Network_Id (B) and then A = B)
     with Global => null;

   function Names_This_Install (Record_Fingerprint, Own_Fingerprint : String) return Boolean is
     (Reef_Enrol_Record_Pkg.Is_Hex64 (Record_Fingerprint) and then
      Reef_Enrol_Record_Pkg.Is_Hex64 (Own_Fingerprint) and then
      Record_Fingerprint = Own_Fingerprint)
     with Global => null;

   function In_Date (Issued_At, Expires_At, Now : String) return Boolean is
     (Reef_Enrol_Record_Pkg.Is_Unixtime (Issued_At) and then
      Reef_Enrol_Record_Pkg.Is_Unixtime (Expires_At) and then
      Reef_Enrol_Record_Pkg.Is_Unixtime (Now) and then
      not Reef_Enrol_Record_Pkg.Later_Than (Issued_At, Now) and then
      Reef_Enrol_Record_Pkg.Later_Than (Expires_At, Now))
     with Global => null;

   function Trusted (Pin : String; Signer_Digest : String; Record_Present : Boolean; Signature_Verified : Boolean; Record_Fingerprint : String; Own_Fingerprint : String) return Boolean is
     (Is_Network_Id (Pin) and then
      Record_Present and then
      Signature_Verified and then
      Same_Network (Signer_Digest, Pin) and then
      Names_This_Install (Record_Fingerprint, Own_Fingerprint))
     with Global => null;

   function Current (Role : String; Issued_At : String; Expires_At : String; Now : String; Revocation : Revocation_State) return Boolean is
     (Reef_Enrol_Record_Pkg.Is_Role (Role) and then
      In_Date (Issued_At, Expires_At, Now) and then
      Revocation = Rev_Clear)
     with Global => null;

   function Link_Established (Pin : String; Signer_Digest : String; Record_Present : Boolean; Signature_Verified : Boolean; Record_Fingerprint : String; Own_Fingerprint : String; Role : String; Issued_At : String; Expires_At : String; Now : String; Revocation : Revocation_State) return Boolean is
     (Trusted (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint) and then
      Current (Role, Issued_At, Expires_At, Now, Revocation))
     with Global => null;

   function Trust_Refusal (Pin : String; Signer_Digest : String; Record_Present : Boolean; Signature_Verified : Boolean; Record_Fingerprint : String; Own_Fingerprint : String) return Reason_Kind is
     ((if not Is_Network_Id (Pin) then No_Network
       elsif not Record_Present then No_Record
       elsif not Signature_Verified then Unverified
       elsif not Same_Network (Signer_Digest, Pin) then Other_Network
       elsif not Names_This_Install (Record_Fingerprint, Own_Fingerprint) then Another_Install
       else None))
     with Global => null,
          Post => ((Trust_Refusal'Result = None) = Trusted (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint) and then
                   (if not Is_Network_Id (Pin) then Trust_Refusal'Result = No_Network) and then
                   (if (Is_Network_Id (Pin) and then not Record_Present) then Trust_Refusal'Result = No_Record) and then
                   (if (Is_Network_Id (Pin) and then Record_Present and then not Signature_Verified) then Trust_Refusal'Result = Unverified) and then
                   (if (Is_Network_Id (Pin) and then Record_Present and then Signature_Verified and then not Same_Network (Signer_Digest, Pin)) then Trust_Refusal'Result = Other_Network) and then
                   (if (Is_Network_Id (Pin) and then Record_Present and then Signature_Verified and then Same_Network (Signer_Digest, Pin) and then not Names_This_Install (Record_Fingerprint, Own_Fingerprint)) then Trust_Refusal'Result = Another_Install));

   function Currency_Refusal (Role : String; Issued_At : String; Expires_At : String; Now : String; Revocation : Revocation_State) return Reason_Kind is
     ((if not Reef_Enrol_Record_Pkg.Is_Role (Role) then Not_Sender
       elsif not In_Date (Issued_At, Expires_At, Now) then Not_In_Date
       elsif Revocation = Rev_Revoked then Revoked
       elsif Revocation = Rev_Unknown then Revocation_Unknown
       else None))
     with Global => null,
          Post => ((Currency_Refusal'Result = None) = Current (Role, Issued_At, Expires_At, Now, Revocation) and then
                   (if not Reef_Enrol_Record_Pkg.Is_Role (Role) then Currency_Refusal'Result = Not_Sender) and then
                   (if (Reef_Enrol_Record_Pkg.Is_Role (Role) and then not In_Date (Issued_At, Expires_At, Now)) then Currency_Refusal'Result = Not_In_Date) and then
                   (if (Reef_Enrol_Record_Pkg.Is_Role (Role) and then In_Date (Issued_At, Expires_At, Now) and then Revocation = Rev_Revoked) then Currency_Refusal'Result = Revoked) and then
                   (if (Reef_Enrol_Record_Pkg.Is_Role (Role) and then In_Date (Issued_At, Expires_At, Now) and then Revocation = Rev_Unknown) then Currency_Refusal'Result = Revocation_Unknown));

   function Link_Refusal (Pin : String; Signer_Digest : String; Record_Present : Boolean; Signature_Verified : Boolean; Record_Fingerprint : String; Own_Fingerprint : String; Role : String; Issued_At : String; Expires_At : String; Now : String; Revocation : Revocation_State) return Reason_Kind is
     ((if Trust_Refusal (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint) /= None then Trust_Refusal (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint)
       else Currency_Refusal (Role, Issued_At, Expires_At, Now, Revocation)))
     with Global => null,
          Post => ((Link_Refusal'Result = None) = Link_Established (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint, Role, Issued_At, Expires_At, Now, Revocation) and then
                   (if not Trusted (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint) then Link_Refusal'Result = Trust_Refusal (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint)) and then
                   (if Trusted (Pin, Signer_Digest, Record_Present, Signature_Verified, Record_Fingerprint, Own_Fingerprint) then Link_Refusal'Result = Currency_Refusal (Role, Issued_At, Expires_At, Now, Revocation)) and then
                   (if Is_Zero_Pin (Pin) then Link_Refusal'Result = No_Network) and then
                   (if not Record_Present then Link_Refusal'Result /= None));

end Network_Link_Pkg;
