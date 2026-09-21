--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 460533a474e51d62a80cd15eb2becc5d5cb1146747145dd022e24128c7a4117d
--
package Tower_Envelope_Pkg with SPARK_Mode is
   --  PURPOSE: questions about LINE 2 of a tower SHARER bundle, the envelope,
   --  and about the RECEIPT RECORD it carries. Both are pinned character by
   --  character; nothing is searched for.
   --  USAGE: find the three closing quotes (R_Last = S_Last + Receipt_Span),
   --  ask Envelope_Is ONCE, slice, decode, VERIFY, then ask Receipt_Names.

   Max_Line       : constant := 16384;
   Seal_First     : constant := 10;
   Head_Last      : constant := 9;
   Mid_1_Length   : constant := 13;
   Receipt_Offset : constant := 14;
   Receipt_Span   : constant := 181;
   Mid_2_Length   : constant := 18;
   Receipt_Seal_Offset : constant := 19;
   Tail_Length    : constant := 2;
   Digest_Length  : constant := 64;
   Receipt_Length : constant := 84;
   Receipt_Head_Last : constant := 18;
   Digest_First   : constant := 19;
   Digest_Last    : constant := 82;
   Receipt_Tail_First : constant := 83;

   subtype Index_Type is Natural range 0 .. Max_Line;

   Head : constant String := '{' & '"' & "seal" & '"' & ':' & '"';
   Mid_1 : constant String := '"' & ',' & '"' & "receipt" & '"' & ':' & '"';
   Mid_2 : constant String :=
     '"' & ',' & '"' & "receipt_seal" & '"' & ':' & '"';
   Tail : constant String := '"' & '}';
   Receipt_Head : constant String :=
     '{' & '"' & "bundle_sha256" & '"' & ':' & '"';

   function Is_Hex_Text (S : String) return Boolean
   is (S'Length >= 2 and then
       S'Length <= Max_Line and then
       S'Length mod 2 = 0 and then
       (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f'))
   with Global => null,
        Post => (Is_Hex_Text'Result =
                   (not (S'Length < 2 or else S'Length > Max_Line
                         or else S'Length mod 2 /= 0 or else
                         (for some I in S'Range =>
                            S (I) not in '0' .. '9' | 'a' .. 'f'))))
               and then
               (if Is_Hex_Text'Result then (S'Length >= 2 and then S'Length mod 2 = 0));

   function Is_Hex_Digest (S : String) return Boolean
   is (S'Length = Digest_Length and then
       (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f'))
   with Global => null,
        Post => (Is_Hex_Digest'Result =
                   (not (S'Length /= Digest_Length or else
                         (for some I in S'Range =>
                            S (I) not in '0' .. '9' | 'a' .. 'f'))))
               and then
               (if Is_Hex_Digest'Result then S'Length = Digest_Length);

   function Envelope_Is (Line : String; S_Last : Index_Type;
                         R_Last : Index_Type; Q_Last : Index_Type) return Boolean
   is (Q_Last = Line'Length - Tail_Length and then
       R_Last = S_Last + Receipt_Span and then
       Q_Last > R_Last + Receipt_Seal_Offset and then
       Line (1 .. Head_Last) = Head and then
       Is_Hex_Text (Line (Seal_First .. S_Last)) and then
       Line (S_Last + 1 .. S_Last + Mid_1_Length) = Mid_1 and then
       Is_Hex_Text (Line (S_Last + Receipt_Offset .. R_Last)) and then
       Line (R_Last + 1 .. R_Last + Mid_2_Length) = Mid_2 and then
       Is_Hex_Text (Line (R_Last + Receipt_Seal_Offset .. Q_Last)) and then
       Line (Q_Last + 1 .. Q_Last + Tail_Length) = Tail)
   with Global => null,
        Pre => Line'First = 1,
        Post => (Envelope_Is'Result =
                   (not (Q_Last /= Line'Length - Tail_Length or else
                         R_Last /= S_Last + Receipt_Span or else
                         Q_Last <= R_Last + Receipt_Seal_Offset or else
                         Line (1 .. Head_Last) /= Head or else
                         not Is_Hex_Text (Line (Seal_First .. S_Last)) or else
                         Line (S_Last + 1 .. S_Last + Mid_1_Length) /= Mid_1 or else
                         not Is_Hex_Text (Line (S_Last + Receipt_Offset .. R_Last)) or else
                         Line (R_Last + 1 .. R_Last + Mid_2_Length) /= Mid_2 or else
                         not Is_Hex_Text (Line (R_Last + Receipt_Seal_Offset .. Q_Last)) or else
                         Line (Q_Last + 1 .. Q_Last + Tail_Length) /= Tail)))
               and then
               (if Envelope_Is'Result then (S_Last < R_Last and then R_Last < Q_Last
                                            and then Q_Last + Tail_Length = Line'Last));

   function Receipt_Names (Rec : String; Digest : String) return Boolean
   is (Rec'Length = Receipt_Length and then
       Rec (1 .. Receipt_Head_Last) = Receipt_Head and then
       Rec (Receipt_Tail_First .. Receipt_Length) = Tail and then
       Is_Hex_Digest (Digest) and then
       Rec (Digest_First .. Digest_Last) = Digest)
   with Global => null,
        Pre => Rec'First = 1,
        Post => (Receipt_Names'Result =
                   (not (Rec'Length /= Receipt_Length or else
                         Rec (1 .. Receipt_Head_Last) /= Receipt_Head or else
                         Rec (Receipt_Tail_First .. Receipt_Length) /= Tail or else
                         not Is_Hex_Digest (Digest) or else
                         Rec (Digest_First .. Digest_Last) /= Digest)))
               and then
               (if Receipt_Names'Result then Is_Hex_Digest (Digest));

end Tower_Envelope_Pkg;
