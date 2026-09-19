--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1453643e444efd1ea67530b1fdf493bd71a2e42ea3e2fc7efb81de398a10ce8b
--
--  Palais_Enrol_Pkg -- the palais.enrol edge of CRUCIBLE's door: one call, one step of enrolment with the Reef.
--  Purpose: make this factory's own key pair (the private half never leaves it), ask the Reef over the reef rail for a
--  signed key-claim record, and keep that record ONLY when the proven Reef_Key_Claim_Pkg.Accept_Key says so. It decides
--  nothing itself: every accept/refuse is Accept_Key's, reached from facts the slots record.
--  One request, one reply: the door cannot wait ten minutes for a human. The first call starts an enrolment and returns
--  the code the human types at thereef.ink; each later call polls ONCE and answers pending, accepted or refused.
--  Nothing listens: every connection is opened by this edge.
--  Brief: ObVault/designs/BRIEF_palais_enrol_edge_2026-09-19.md (DESIGN_palais_enrol_2026-09-19, accepted by Tony).
--  Usage:
--     Palais_Enrol_Pkg.Step (Codename => "otter", Where => Paths, Reply => Text);
package Palais_Enrol_Pkg with SPARK_Mode => Off is

   type Text_Access is access String;

   --  Every file the edge touches, named by the caller: the door passes the shipped places; the probe passes a
   --  scratch tree. Signers_Digest is the SHA-256 (64 lower-case hex) the pinned allowed_signers file's FIRST LINE must have
   --  (the line without its line feed).
   type Paths is record
      Conf_Path      : Text_Access;   --  config/rail.conf
      Key_Dir        : Text_Access;   --  ~/.crucible/key  (id_ed25519, id_ed25519.pub, factory-id)
      State_Dir      : Text_Access;   --  state/           (reef-enrol-pending.json, reef-key.json)
      Signers_Path   : Text_Access;   --  config/reef-allowed-signers
      Signers_Digest : Text_Access;
      Ssh_Keygen     : Text_Access;   --  /usr/bin/ssh-keygen
   end record;

   --  Reply is ONE flat JSON object, no line feed:
   --    {"enrol":"pending","user_code":"...","url":"..."}
   --    {"enrol":"accepted","codename":"...","role":"sender|solver","expires_at":"..."}
   --    {"enrol":"already","fingerprint":"..."}
   --    {"enrol":"refused","reason":"<word>"}
   procedure Step
     (Codename : String;
      Where    : Paths;
      Reply    : out Text_Access);

end Palais_Enrol_Pkg;
