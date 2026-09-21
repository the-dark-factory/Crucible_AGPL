--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fb549a742acf74216a4468ece06861af65c8717303b413eae551d75c06d14de7
--
--  Tower_Fetch_Pkg -- CRUCIBLE's FETCH edge: at forge start, ask the Reef what catalog is current and, if it names a
--  version higher than this factory's running version, bring that ONE file down and put it where the shipped import
--  reads from (tower/sharer.bundle). It DECIDES NOTHING: every judgement about the index text and the wire replies is
--  the proven Tower_Index_Pkg's; the file's acceptance is Tower_Import_Pkg's and the proven Tower_Admission_Pkg's,
--  exactly as today (the transport brief of 2026-09-21 section 2; the loopback build brief, piece B; the cover table
--  BRIEF_tower_index_pkg_cover_table_2026-09-21 section 4; Tony's rulings D1(c) ONE stream with an index that can name
--  more than one source, D3(a) automatic at forge start, rate-limited, never blocking).
--  USAGE: call Fetch once per forge, AFTER Tower_Base_Check_Edge.Check has let the door through and BEFORE
--  Tower_Import_Pkg.Import. It never raises and never stops a forge. Word is Tower_Index_Pkg.Outcome's, as text:
--    no_reef_rail      config/rail.conf has no valid reef line (nothing asked, no row written)
--    rate_limited      the last attempt was under Tower_Index_Pkg.Interval_Seconds ago (nothing asked, no row)
--    reef_unreachable  the relay gave no usable line for the index (row written; the forge continues on what it has)
--    index_unreadable  a line came back but it is not an index by Tower_Index_Pkg's shape facts (row written)
--    index_unverified  the index's seal under df-index does not verify against the trust file beside the binary
--                      (row written; nothing is read from an unverified index, not even expires)
--    index_stale       the index's expires is not after the clock: recorded, the forge continues on what it has
--    current           the index names nothing newer than the running version (row written; nothing fetched)
--    fetch_failed      the index named a newer file but the relay gave no usable line for it (row written)
--    fetched           the file was written to tower/sharer.bundle; the row says whether its sha256 matched the
--                      index's (digest_matches, Tower_Index_Pkg.Digest_Names). RECORDED, not judged: the import judges.
--  THE WIRE and THE INDEX FILE are Tower_Index_Pkg's (Index_Reply_Head, Fetch_Reply_Head, Reply_Tail; two lines, line 1
--  sealed whole, line 2 the one-field envelope the admitted Tower_Receipt_Pkg.Is_Seal_Line names).
--  RATE LIMIT: one row per attempt in state/tower-fetch.jsonl; the newest row's `at` gates the next attempt. Deleting
--  the file resets it. The row is also the read-only record of what was fetched, when, and with what outcome (the
--  release has no doctor tool yet -- INSTALL.md says so -- so the row and the standard-error line are the doctor line).
--  THE TRUST FILE for the index seal is the same allowed_signers beside the binary that the import uses, generated
--  at build time by bin/stamp_signers from Tower_Keys_Pkg. No agent-callable pull verb exists (the rulings).
--  SEAT-WRITTEN (an edge; SPARK_Mode Off): reading the rail, the socket exchange, two ssh-keygen spawns, hex decode,
--  sha256, the row, the file, the clock, and the array walk that hands each entry to the proven fold.
with Ada.Strings.Unbounded;

package Tower_Fetch_Pkg with SPARK_Mode => Off is

   Conf_Path       : constant String := "config/rail.conf";
   Bundle_Path     : constant String := "tower/sharer.bundle";
   Ledger_Path     : constant String := "state/tower.jsonl";
   Row_Path        : constant String := "state/tower-fetch.jsonl";
   Work_Dir        : constant String := "state/tower-fetch";
   Signers_Name    : constant String := "allowed_signers";
   Ssh_Keygen      : constant String := "/usr/bin/ssh-keygen";
   Index_Namespace : constant String := "df-index";

   --  The two requests, one line each (the replies' shapes are Tower_Index_Pkg's).
   Index_Request : constant String := "{""op"":""index""}";
   Fetch_Head    : constant String := "{""op"":""fetch"",""name"":""";
   Fetch_Tail    : constant String := """}";

   --  A ledger or row line is read in at most this many characters (as the import reads it).
   Line_Bound : constant := 4_096;

   procedure Fetch (Word : out Ada.Strings.Unbounded.Unbounded_String);

end Tower_Fetch_Pkg;
