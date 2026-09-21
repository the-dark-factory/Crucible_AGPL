--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0585a5955391abf468d6891b6c7ebd13cdab5b34cc43d9af78bbc4dfbd1963f8
--
with Tower_Envelope_Pkg;
with Tower_Payload_Pkg;
with Tower_Stamp_Pkg;

package Tower_Pack_Pkg with SPARK_Mode is
   --  PURPOSE: the TEXT of a tower SHARER bundle this factory PACKS, and the
   --  outcome of packing: which ledger rows are shareable, what an entry is,
   --  what line 1, the receipt and the envelope are, and the word for the run.
   --  USAGE: the edge measures and hands text; every shape here is the shape
   --  the IMPORT side pins in Tower_Payload_Pkg and Tower_Envelope_Pkg.

   Max_Name  : constant := 64;
   Max_Word  : constant := 32;
   Max_Cope  : constant := 400;
   Timestamp_Length : constant := 20;
   Envelope_Fixed   : constant := 210;

   function Is_Core_Name (S : String) return Boolean
     is (S'Length >= 1 and then S'Length <= Max_Name
         and then (for all I in S'Range => S (I) in 'a' .. 'z' | '0' .. '9' | '_')
         and then S (S'First) in 'a' .. 'z')
     with Global => null,
          Post => (Is_Core_Name'Result =
                      (not (S'Length < 1 or else S'Length > Max_Name
                            or else (for some I in S'Range => S (I) not in 'a' .. 'z' | '0' .. '9' | '_')
                            or else S (S'First) not in 'a' .. 'z')))
                  and then (if Is_Core_Name'Result then S'Length in 1 .. Max_Name);

   function Is_Word (S : String) return Boolean
     is (S'Length >= 1 and then S'Length <= Max_Word
         and then (for all I in S'Range => S (I) in 'a' .. 'z' | '_'))
     with Global => null,
          Post => (Is_Word'Result =
                      (not (S'Length < 1 or else S'Length > Max_Word
                            or else (for some I in S'Range => S (I) not in 'a' .. 'z' | '_'))))
                  and then (if Is_Word'Result then S'Length in 1 .. Max_Word);

   function Is_Cope_Text (S : String) return Boolean
     is (S'Length >= 1 and then S'Length <= Max_Cope
         and then (for all I in S'Range => S (I) in ' ' .. '~')
         and then (for all I in S'Range => S (I) /= '"')
         and then (for all I in S'Range => S (I) /= Character'Val (92)))
     with Global => null,
          Post => (Is_Cope_Text'Result =
                      (not (S'Length < 1 or else S'Length > Max_Cope
                            or else (for some I in S'Range => S (I) not in ' ' .. '~')
                            or else (for some I in S'Range => S (I) = '"')
                            or else (for some I in S'Range => S (I) = Character'Val (92)))))
                  and then (if Is_Cope_Text'Result then S'Length in 1 .. Max_Cope);

   function Is_Timestamp_Text (S : String) return Boolean
     is (S'Length = Timestamp_Length
         and then (for all I in S'Range => S (I) in '0' .. '9' | '-' | 'T' | ':' | 'Z'))
     with Global => null,
          Post => (Is_Timestamp_Text'Result =
                      (not (S'Length /= Timestamp_Length
                            or else (for some I in S'Range => S (I) not in '0' .. '9' | '-' | 'T' | ':' | 'Z'))))
                  and then (if Is_Timestamp_Text'Result then S'Length = Timestamp_Length);

   function Later (A : String; B : String) return Boolean
     is (A > B)
     with Global => null,
          Pre => Is_Timestamp_Text (A) and then Is_Timestamp_Text (B),
          Post => (Later'Result = (A > B))
                  and then (if A = B then not Later'Result);

   function Shareable (Prove_Ok : Boolean; Clean : Boolean; Name_Ok : Boolean; Digest_Ok : Boolean) return Boolean
     is (Prove_Ok and then Clean and then Name_Ok and then Digest_Ok)
     with Global => null,
          Post => (Shareable'Result = (Prove_Ok and then Clean and then Name_Ok and then Digest_Ok))
                  and then (if not Prove_Ok then not Shareable'Result)
                  and then (if not Clean then not Shareable'Result)
                  and then (if not Name_Ok then not Shareable'Result)
                  and then (if not Digest_Ok then not Shareable'Result);

   Component_Head : constant String :=
     '{' & '"' & "kind" & '"' & ':' & '"' & "component" & '"' & ',' & '"' & "core" & '"' & ':' & '"';
   Component_Mid  : constant String := '"' & ',' & '"' & "source_sha256" & '"' & ':' & '"';
   Entry_Tail     : constant String := '"' & '}';

   function Component_Entry (Name : String; Digest : String) return String
     is (Component_Head & Name & Component_Mid & Digest & Entry_Tail)
     with Global => null,
          Pre => Is_Core_Name (Name) and then Tower_Stamp_Pkg.Is_Hex_Digest (Digest),
          Post => (Component_Entry'Result'Length =
                      Component_Head'Length + Name'Length + Component_Mid'Length + Digest'Length + Entry_Tail'Length)
                  and then (Component_Entry'Result'First = 1)
                  and then (Component_Entry'Result (1) = '{')
                  and then (Component_Entry'Result (Component_Entry'Result'Length) = '}');

   Cope_Head  : constant String :=
     '{' & '"' & "kind" & '"' & ':' & '"' & "cope" & '"' & ',' & '"' & "entry_id" & '"' & ':' & '"';
   Cope_Mid_1 : constant String := '"' & ',' & '"' & "model_digest" & '"' & ':' & '"';
   Cope_Mid_2 : constant String := '"' & ',' & '"' & "stage" & '"' & ':' & '"';
   Cope_Mid_3 : constant String := '"' & ',' & '"' & "refusal_class" & '"' & ':' & '"';
   Cope_Mid_4 : constant String := '"' & ',' & '"' & "tier" & '"' & ':' & '"';
   Cope_Mid_5 : constant String := '"' & ',' & '"' & "cope" & '"' & ':' & '"';
   Cope_Mid_6 : constant String := '"' & ',' & '"' & "evidence" & '"' & ':' & '"';

   function Cope_Entry (Entry_Id : String; Model_Digest : String; Stage : String; Class : String;
                        Tier : String; Cope : String; Evidence : String) return String
     is (Cope_Head & Entry_Id & Cope_Mid_1 & Model_Digest & Cope_Mid_2 & Stage & Cope_Mid_3 & Class
         & Cope_Mid_4 & Tier & Cope_Mid_5 & Cope & Cope_Mid_6 & Evidence & Entry_Tail)
     with Global => null,
          Pre => Tower_Stamp_Pkg.Is_Hex_Digest (Entry_Id) and then Tower_Stamp_Pkg.Is_Hex_Digest (Model_Digest)
                 and then Is_Word (Stage) and then Is_Word (Class) and then Is_Word (Tier)
                 and then Is_Cope_Text (Cope) and then Tower_Stamp_Pkg.Is_Version_Text (Evidence),
          Post => (Cope_Entry'Result'Length =
                      Cope_Head'Length + Entry_Id'Length + Cope_Mid_1'Length + Model_Digest'Length
                      + Cope_Mid_2'Length + Stage'Length + Cope_Mid_3'Length + Class'Length
                      + Cope_Mid_4'Length + Tier'Length + Cope_Mid_5'Length + Cope'Length
                      + Cope_Mid_6'Length + Evidence'Length + Entry_Tail'Length)
                  and then (Cope_Entry'Result'First = 1)
                  and then (Cope_Entry'Result (1) = '{')
                  and then (Cope_Entry'Result (Cope_Entry'Result'Length) = '}');

   Head_Open  : constant String := '{' & '"' & "version" & '"' & ':';
   Head_Mid   : constant String := ',' & '"' & "expires" & '"' & ':' & '"';
   Head_Close : constant String := '"' & ',' & '"' & "entries" & '"' & ':' & '[';
   Line_Tail  : constant String := ']' & '}';

   function Head (Version : String; Expires : String) return String
     is (Head_Open & Version & Head_Mid & Expires & Head_Close)
     with Global => null,
          Pre => Tower_Stamp_Pkg.Is_Version_Text (Version) and then Tower_Payload_Pkg.Is_Seconds_Text (Expires),
          Post => (Head'Result'Length =
                      Head_Open'Length + Version'Length + Head_Mid'Length + Expires'Length + Head_Close'Length)
                  and then (Head'Result'First = 1)
                  and then (Head'Result (1) = '{')
                  and then (Head'Result (Head'Result'Length) = '[');

   function Line_1 (Head_Text : String; Interior : String) return String
     is (Head_Text & Interior & Line_Tail)
     with Global => null,
          Pre => Head_Text'First = 1
                 and then Interior'First = 1
                 and then Head_Text'Length <= Tower_Payload_Pkg.Max_Line
                 and then Interior'Length <= Tower_Payload_Pkg.Max_Line
                 and then Head_Text'Length + Interior'Length + Line_Tail'Length <= Tower_Payload_Pkg.Max_Line,
          Post => (Line_1'Result'Length = Head_Text'Length + Interior'Length + Line_Tail'Length)
                  and then (Line_1'Result'First = 1)
                  and then (Line_1'Result'Length <= Tower_Payload_Pkg.Max_Line)
                  and then (Line_1'Result (Line_1'Result'Length) = '}');

   type Completion_Facts is record
      have_source      : Boolean := False;
      sealed           : Boolean := False;
      receipt_names_it : Boolean := False;
      written          : Boolean := False;
   end record;

   function Receipt_Text (Digest : String) return String
     is (Tower_Envelope_Pkg.Receipt_Head & Digest & Tower_Envelope_Pkg.Tail)
     with Global => null,
          Pre => Tower_Stamp_Pkg.Is_Hex_Digest (Digest),
          Post => (Receipt_Text'Result'Length = Tower_Envelope_Pkg.Receipt_Length)
                  and then (Receipt_Text'Result'First = 1)
                  and then (Tower_Envelope_Pkg.Receipt_Names (Receipt_Text'Result, Digest));

   function Envelope_Text (Seal_Hex : String; Receipt_Hex : String; Receipt_Seal_Hex : String) return String
     is (Tower_Envelope_Pkg.Head & Seal_Hex & Tower_Envelope_Pkg.Mid_1 & Receipt_Hex
         & Tower_Envelope_Pkg.Mid_2 & Receipt_Seal_Hex & Tower_Envelope_Pkg.Tail)
     with Global => null,
          Pre => Tower_Envelope_Pkg.Is_Hex_Text (Seal_Hex)
                 and then Receipt_Hex'Length = 2 * Tower_Envelope_Pkg.Receipt_Length
                 and then Tower_Envelope_Pkg.Is_Hex_Text (Receipt_Hex)
                 and then Tower_Envelope_Pkg.Is_Hex_Text (Receipt_Seal_Hex)
                 and then Seal_Hex'Length + Receipt_Seal_Hex'Length <= Tower_Envelope_Pkg.Max_Line - Envelope_Fixed,
          Post => (Envelope_Text'Result'Length = Seal_Hex'Length + Receipt_Seal_Hex'Length + Envelope_Fixed)
                  and then (Envelope_Text'Result'First = 1)
                  and then (Envelope_Text'Result'Length <= Tower_Envelope_Pkg.Max_Line)
                  and then (Tower_Envelope_Pkg.Envelope_Is
                              (Envelope_Text'Result,
                               Tower_Envelope_Pkg.Head_Last + Seal_Hex'Length,
                               Tower_Envelope_Pkg.Head_Last + Seal_Hex'Length + Tower_Envelope_Pkg.Receipt_Span,
                               Envelope_Text'Result'Length - Tower_Envelope_Pkg.Tail_Length));

   type Pack_Facts is record
      have_ledger  : Boolean := False;
      have_key     : Boolean := False;
      have_entries : Boolean := False;
      fits         : Boolean := False;
      signed       : Boolean := False;
      written      : Boolean := False;
   end record;

   type Outcome_Kind is
     (Out_Packed, Out_Packed_Unreceipted, Out_Refused_No_Ledger, Out_Refused_No_Key,
      Out_Refused_Nothing_Shareable, Out_Refused_Too_Large, Out_Refused_Sign_Failed,
      Out_Refused_Write_Failed, Out_Refused_No_Source, Out_Refused_Receipt_Mismatch);

   function Outcome (F : Pack_Facts) return Outcome_Kind
     is ((if not F.have_ledger then Out_Refused_No_Ledger
          elsif not F.have_key then Out_Refused_No_Key
          elsif not F.have_entries then Out_Refused_Nothing_Shareable
          elsif not F.fits then Out_Refused_Too_Large
          elsif not F.signed then Out_Refused_Sign_Failed
          elsif not F.written then Out_Refused_Write_Failed
          else Out_Packed_Unreceipted))
     with Global => null,
          Post => ((Outcome'Result = Out_Packed_Unreceipted) =
                      (F.have_ledger and then F.have_key and then F.have_entries and then F.fits
                       and then F.signed and then F.written))
                  and then (Outcome'Result /= Out_Packed)
                  and then (if not F.have_ledger then Outcome'Result = Out_Refused_No_Ledger)
                  and then (if F.have_ledger and then not F.have_key then Outcome'Result = Out_Refused_No_Key)
                  and then (if F.have_ledger and then F.have_key and then not F.have_entries then
                               Outcome'Result = Out_Refused_Nothing_Shareable)
                  and then (if F.have_ledger and then F.have_key and then F.have_entries and then not F.fits then
                               Outcome'Result = Out_Refused_Too_Large)
                  and then (if F.have_ledger and then F.have_key and then F.have_entries and then F.fits
                              and then not F.signed then Outcome'Result = Out_Refused_Sign_Failed)
                  and then (if F.have_ledger and then F.have_key and then F.have_entries and then F.fits
                              and then F.signed and then not F.written then Outcome'Result = Out_Refused_Write_Failed)
                  and then (if not F.signed then Outcome'Result /= Out_Packed_Unreceipted);

   function Completion (C : Completion_Facts) return Outcome_Kind
     is ((if not C.have_source then Out_Refused_No_Source
          elsif not C.sealed then Out_Refused_Sign_Failed
          elsif not C.receipt_names_it then Out_Refused_Receipt_Mismatch
          elsif not C.written then Out_Refused_Write_Failed
          else Out_Packed))
     with Global => null,
          Post => ((Completion'Result = Out_Packed) =
                      (C.have_source and then C.sealed and then C.receipt_names_it and then C.written))
                  and then (Completion'Result /= Out_Packed_Unreceipted)
                  and then (if not C.have_source then Completion'Result = Out_Refused_No_Source)
                  and then (if C.have_source and then not C.sealed then Completion'Result = Out_Refused_Sign_Failed)
                  and then (if C.have_source and then C.sealed and then not C.receipt_names_it then
                               Completion'Result = Out_Refused_Receipt_Mismatch)
                  and then (if C.have_source and then C.sealed and then C.receipt_names_it and then not C.written then
                               Completion'Result = Out_Refused_Write_Failed)
                  and then (if not C.receipt_names_it then Completion'Result /= Out_Packed);

end Tower_Pack_Pkg;
