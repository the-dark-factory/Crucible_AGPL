--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9c6805fc2f77bc9650b71173cb472bda3234341ebb3a7199b77dc0262750efbc
--
with Tower_Envelope_Pkg;

package Tower_Receipt_Pkg with SPARK_Mode is
   --  PURPOSE: what the ADMITTER judges before it puts its name to a packed
   --  bundle: that the unreceipted file's second line is one seal and nothing
   --  else, where that seal's hex lies, what a signer's name may look like,
   --  and the word for the run -- issued exactly when every fact was measured.
   --  USAGE: the edge measures and hands text and facts; the receipt text is
   --  Tower_Pack_Pkg.Receipt_Text, and the import side re-checks all of it.

   Seal_Line_Min : constant := 13;
   Max_Principal : constant := 128;

   function Is_Seal_Line (S : String) return Boolean
   is (S'Length >= Seal_Line_Min
       and then S'Length <= Tower_Envelope_Pkg.Max_Line
       and then S (1 .. Tower_Envelope_Pkg.Head_Last) = Tower_Envelope_Pkg.Head
       and then S (S'Length - Tower_Envelope_Pkg.Tail_Length + 1 .. S'Length) = Tower_Envelope_Pkg.Tail
       and then Tower_Envelope_Pkg.Is_Hex_Text
                  (S (Tower_Envelope_Pkg.Seal_First .. S'Length - Tower_Envelope_Pkg.Tail_Length)))
   with Global => null,
        Pre => S'First = 1,
        Post => (Is_Seal_Line'Result =
                   (not (S'Length < Seal_Line_Min
                         or else S'Length > Tower_Envelope_Pkg.Max_Line
                         or else S (1 .. Tower_Envelope_Pkg.Head_Last) /= Tower_Envelope_Pkg.Head
                         or else S (S'Length - Tower_Envelope_Pkg.Tail_Length + 1 .. S'Length)
                                   /= Tower_Envelope_Pkg.Tail
                         or else not Tower_Envelope_Pkg.Is_Hex_Text
                                   (S (Tower_Envelope_Pkg.Seal_First
                                       .. S'Length - Tower_Envelope_Pkg.Tail_Length)))))
                and then (if Is_Seal_Line'Result then S'Length in Seal_Line_Min .. Tower_Envelope_Pkg.Max_Line);

   function Seal_Last (S : String) return Tower_Envelope_Pkg.Index_Type
   is (S'Length - Tower_Envelope_Pkg.Tail_Length)
   with Global => null,
        Pre => S'First = 1 and then Is_Seal_Line (S),
        Post => (Seal_Last'Result = S'Length - Tower_Envelope_Pkg.Tail_Length)
                and then (Seal_Last'Result >= Tower_Envelope_Pkg.Seal_First + 1)
                and then (Seal_Last'Result < S'Length)
                and then Tower_Envelope_Pkg.Is_Hex_Text
                           (S (Tower_Envelope_Pkg.Seal_First .. Seal_Last'Result));

   function Is_Principal (S : String) return Boolean
   is (S'Length >= 1 and then S'Length <= Max_Principal
       and then (for all I in S'Range =>
                   S (I) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '@' | '.' | '_' | '-'))
   with Global => null,
        Post => (Is_Principal'Result =
                   (not (S'Length < 1 or else S'Length > Max_Principal
                         or else (for some I in S'Range =>
                                   S (I) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '@' | '.' | '_' | '-'))))
                and then (if Is_Principal'Result then S'Length in 1 .. Max_Principal);

   type Issue_Facts is record
      have_source : Boolean := False;
      have_key    : Boolean := False;
      sealed      : Boolean := False;
      payload_ok  : Boolean := False;
      seal_known  : Boolean := False;
      seal_valid  : Boolean := False;
      not_self    : Boolean := False;
      signed      : Boolean := False;
      written     : Boolean := False;
   end record;

   type Outcome_Kind is
     (Out_Issued, Out_Refused_No_Source, Out_Refused_No_Key, Out_Refused_Not_Sealed,
      Out_Refused_Not_A_Payload, Out_Refused_Seal_Unknown, Out_Refused_Seal_Invalid,
      Out_Refused_Self_Sealed, Out_Refused_Sign_Failed, Out_Refused_Write_Failed);

   function Outcome (F : Issue_Facts) return Outcome_Kind
   is ((if not F.have_source then Out_Refused_No_Source
        elsif not F.have_key then Out_Refused_No_Key
        elsif not F.sealed then Out_Refused_Not_Sealed
        elsif not F.payload_ok then Out_Refused_Not_A_Payload
        elsif not F.seal_known then Out_Refused_Seal_Unknown
        elsif not F.seal_valid then Out_Refused_Seal_Invalid
        elsif not F.not_self then Out_Refused_Self_Sealed
        elsif not F.signed then Out_Refused_Sign_Failed
        elsif not F.written then Out_Refused_Write_Failed
        else Out_Issued))
   with Global => null,
        Post => ((Outcome'Result = Out_Issued) =
                   (F.have_source and then F.have_key and then F.sealed and then F.payload_ok
                    and then F.seal_known and then F.seal_valid and then F.not_self
                    and then F.signed and then F.written))
                and then (if not F.have_source then Outcome'Result = Out_Refused_No_Source)
                and then (if F.have_source and then not F.have_key then
                            Outcome'Result = Out_Refused_No_Key)
                and then (if F.have_source and then F.have_key and then not F.sealed then
                            Outcome'Result = Out_Refused_Not_Sealed)
                and then (if F.have_source and then F.have_key and then F.sealed
                            and then not F.payload_ok then
                            Outcome'Result = Out_Refused_Not_A_Payload)
                and then (if F.have_source and then F.have_key and then F.sealed and then F.payload_ok
                            and then not F.seal_known then
                            Outcome'Result = Out_Refused_Seal_Unknown)
                and then (if F.have_source and then F.have_key and then F.sealed and then F.payload_ok
                            and then F.seal_known and then not F.seal_valid then
                            Outcome'Result = Out_Refused_Seal_Invalid)
                and then (if F.have_source and then F.have_key and then F.sealed and then F.payload_ok
                            and then F.seal_known and then F.seal_valid and then not F.not_self then
                            Outcome'Result = Out_Refused_Self_Sealed)
                and then (if F.have_source and then F.have_key and then F.sealed and then F.payload_ok
                            and then F.seal_known and then F.seal_valid and then F.not_self
                            and then not F.signed then
                            Outcome'Result = Out_Refused_Sign_Failed)
                and then (if F.have_source and then F.have_key and then F.sealed and then F.payload_ok
                            and then F.seal_known and then F.seal_valid and then F.not_self
                            and then F.signed and then not F.written then
                            Outcome'Result = Out_Refused_Write_Failed)
                and then (if not F.seal_valid then Outcome'Result /= Out_Issued)
                and then (if not F.signed then Outcome'Result /= Out_Issued);

end Tower_Receipt_Pkg;
