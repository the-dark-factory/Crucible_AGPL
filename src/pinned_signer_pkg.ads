--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e531f544dd023822c5d9e756e3e29ccd44cd095cefefe3a1a00e174a1a6db886
--
with Network_Link_Pkg;

package Pinned_Signer_Pkg with SPARK_Mode is

   --  PURPOSE: the pinned-signer judge. A signers file is accepted only when
   --  its bytes are exactly ONE printable line (at most one final line feed,
   --  no tab, no carriage return, no other control character, no leading space
   --  or hash, no trailing space) and that line's digest is the pinned network
   --  id. A zero pin accepts nothing. Signer_Refusal names ONE reason in a
   --  fixed order. Signers_File_Text gives the exact bytes of the private
   --  one-line file.
   --  USAGE: an edge reads the signers file once (bounded), hashes Line_Span
   --  of the bytes, and asks Signer_Refusal; only on None does it write
   --  Signers_File_Text to a fresh private file and run the verify against
   --  that file alone.

   Max_Signers_Bytes : constant := 65536;
   Line_Feed : constant Character := Character'Val (10);
   Space : constant Character := Character'Val (32);
   Hash : constant Character := Character'Val (35);
   Tilde : constant Character := Character'Val (126);

   type Signer_Reason is
     (None, No_Network, No_File, Not_One_Line, Digest_Mismatch);
   --  None means the signers bytes are accepted.

   function Is_Line_Char (C : in Character) return Boolean is
     (C >= Space and then C <= Tilde)
   with Global => null;

   function Ends_In_Line_Feed (Bytes : in String) return Boolean is
     (Bytes'Length >= 1 and then Bytes (Bytes'Last) = Line_Feed)
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0,
        Global => null;

   function Line_Last (Bytes : in String) return Natural is
     (if Ends_In_Line_Feed (Bytes) then Bytes'Last - 1 else Bytes'Last)
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0,
        Post => Line_Last'Result <= Bytes'Last
                and then Bytes'Last - Line_Last'Result <= 1,
        Global => null;

   function Line_Span (Bytes : in String) return String is
     (Bytes (Bytes'First .. Line_Last (Bytes)))
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0,
        Post => (if Ends_In_Line_Feed (Bytes)
                 then Line_Span'Result'Length = Bytes'Length - 1)
                and then
                (if not Ends_In_Line_Feed (Bytes)
                 then Line_Span'Result'Length = Bytes'Length),
        Global => null;

   function One_Line (Bytes : in String) return Boolean is
     (Bytes'Length >= 1
      and then Bytes'Length <= Max_Signers_Bytes
      and then Line_Last (Bytes) >= Bytes'First
      and then (for all I in Bytes'First .. Line_Last (Bytes) =>
                  Is_Line_Char (Bytes (I)))
      and then Bytes (Bytes'First) /= Space
      and then Bytes (Bytes'First) /= Hash
      and then Bytes (Line_Last (Bytes)) /= Space)
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0,
        Global => null;

   function Signer_Accepted
     (Pin : in String;
      Bytes_Present : in Boolean;
      Bytes : in String;
      Line_Digest : in String)
      return Boolean is
     (Network_Link_Pkg.Is_Network_Id (Pin)
      and then Bytes_Present
      and then One_Line (Bytes)
      and then Network_Link_Pkg.Same_Network (Line_Digest, Pin))
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0,
        Global => null;

   function Signer_Refusal
     (Pin : in String;
      Bytes_Present : in Boolean;
      Bytes : in String;
      Line_Digest : in String)
      return Signer_Reason is
     (if not Network_Link_Pkg.Is_Network_Id (Pin) then No_Network
      elsif not Bytes_Present then No_File
      elsif not One_Line (Bytes) then Not_One_Line
      elsif not Network_Link_Pkg.Same_Network (Line_Digest, Pin)
      then Digest_Mismatch
      else None)
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0,
        Post =>
          (Signer_Refusal'Result = None)
          = (Signer_Accepted (Pin, Bytes_Present, Bytes, Line_Digest))
          and then
          (if not Network_Link_Pkg.Is_Network_Id (Pin)
           then Signer_Refusal'Result = No_Network)
          and then
          (if Network_Link_Pkg.Is_Network_Id (Pin)
              and then not Bytes_Present
           then Signer_Refusal'Result = No_File)
          and then
          (if Network_Link_Pkg.Is_Network_Id (Pin)
              and then Bytes_Present
              and then not One_Line (Bytes)
           then Signer_Refusal'Result = Not_One_Line)
          and then
          (if Network_Link_Pkg.Is_Network_Id (Pin)
              and then Bytes_Present
              and then One_Line (Bytes)
              and then not Network_Link_Pkg.Same_Network (Line_Digest, Pin)
           then Signer_Refusal'Result = Digest_Mismatch)
          and then
          (if Network_Link_Pkg.Is_Zero_Pin (Pin)
           then Signer_Refusal'Result = No_Network)
          and then
          (if not One_Line (Bytes)
           then Signer_Refusal'Result /= None),
        Global => null;

   function Signers_File_Text (Bytes : in String) return String is
     (Line_Span (Bytes) & Line_Feed)
   with Pre => Bytes'First = 1 and then Bytes'Last >= 0
               and then One_Line (Bytes),
        Post =>
          Signers_File_Text'Result'Length = Line_Span (Bytes)'Length + 1
          and then
          Signers_File_Text'Result (Signers_File_Text'Result'Last) = Line_Feed
          and then
          Signers_File_Text'Result
            (Signers_File_Text'Result'First
             .. Signers_File_Text'Result'Last - 1)
          = Line_Span (Bytes)
          and then
          (for all I in Signers_File_Text'Result'First
                        .. Signers_File_Text'Result'Last - 1 =>
             Signers_File_Text'Result (I) /= Line_Feed),
        Global => null;

end Pinned_Signer_Pkg;
