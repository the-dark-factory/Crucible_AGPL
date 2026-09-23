#!/usr/bin/env bb
;; release-probe.bb -- can a STRANGER run this tarball?
;;
;; Why this exists: v0.2.0 shipped `base.bundle` flat at the top level while the
;; door reads `tower/base.bundle` relative to cwd. Every forge by every stranger
;; refused with:
;;   {"final":"refused","stopped_at":"tower","reason":"tower_base_missing",
;;    "hint":"restore the base bundle this binary was built with, or replace the binary"}
;; -- a hint that points at a file which IS in the tarball, in the wrong place,
;; and at a binary which is fine. Nothing caught it because the release was
;; assembled by hand and the stranger's-machine run was never done.
;;
;; This unpacks a release tarball into a scratch dir NOTHING ELSE has touched and
;; asks the shipped binary to do the one thing a stranger will do first. It is a
;; last-mile check: it does not read the build, it runs the artefact.
;;
;; ---------------------------------------------------------------------------
;; SHAPE: written to be LOVELACED. The decision is PURE (candidate core:
;; Release_Runnable_Pkg): measured facts in, one verdict out. The edge unpacks
;; and speaks to the door; it judges nothing.
;;   unpacked        Boolean  -- the tarball extracted
;;   door_present    Boolean  -- an executable door is in the tree
;;   door_answers    Boolean  -- initialize returned a serverInfo
;;   base_found      Boolean  -- a forge/intake call did NOT stop at the tower
;;   reaches_intake  Boolean  -- the door got as far as measuring a sheet
;; Theorems:
;;   RUNNABLE-IFF-EVERY-FACT   Runnable <=> all five
;;   A-DOOR-THAT-STOPS-AT-THE-TOWER-IS-NOT-RUNNABLE  (the v0.2.0 defect, named)
;;   NO-DOOR-IS-NOT-RUNNABLE
;;   TOTAL
;; ---------------------------------------------------------------------------
;;
;; Usage: bb tools/release-probe.bb <tarball>
;; Exit:  0 runnable · 1 not runnable · 2 could not unpack

(require '[clojure.string :as str]
         '[babashka.fs :as fs]
         '[babashka.process :as p])

;; === THE DECISION -- pure; becomes Release_Runnable_Pkg ===================

(defn verdict
  [{:keys [unpacked door-present door-answers base-found reaches-intake]}]
  (cond
    (not unpacked)       :unpackable
    (not door-present)   :not-runnable
    (not door-answers)   :not-runnable
    (not base-found)     :not-runnable
    (not reaches-intake) :not-runnable
    :else                :runnable))

;; === THE EDGE -- unpacks and measures; judges nothing =====================

(def sheet
  (str "delivers: package Probe_Pkg with SPARK_Mode, Pure\n"
       "function Negate (A : Boolean) return Boolean\n"
       "post: the result is True exactly when A is False"))

(defn- speak [dir door reqs]
  (let [pre [{:jsonrpc "2.0" :id 1 :method "initialize" :params {}}
             {:jsonrpc "2.0" :method "notifications/initialized"}]
        in  (str (str/join "\n" (map #(cheshire.core/generate-string %) (concat pre reqs))) "\n")]
    (try (:out (p/shell {:in in :out :string :err :string :dir dir :continue true} door))
         (catch Exception _ ""))))

(let [tarball (first *command-line-args*)]
  (when (nil? tarball)
    (println "usage: release-probe.bb <tarball>") (System/exit 2))
  (require '[cheshire.core])
  (let [scratch (str (fs/create-temp-dir {:prefix "release-probe"}))
        tar-abs (str (fs/absolutize tarball))
        ok?     (try (p/shell {:out :string :err :string :dir scratch} "tar" "xzf" tar-abs) true
                     (catch Exception _ false))
        door    (when ok?
                  (->> (fs/glob scratch "**crucible-agpl")
                       (map str) first))
        ;; Start the door from the INSTALL ROOT, not from wherever the binary
        ;; happens to sit. A release that ships bin/crucible-agpl must be started
        ;; from the directory ABOVE bin/, because config/ and tower/ live there.
        ;; (Starting it from bin/ is also a real user trap -- `cd bin && ./crucible-agpl`
        ;; fails exactly like the v0.2.0 layout defect, and the launcher exists
        ;; so nobody has to know that.)
        doordir (when door
                  (let [p (fs/parent door)]
                    (str (if (= "bin" (fs/file-name p)) (fs/parent p) p))))
        ;; MUST be `forge`, not `intake_check`. Only forge runs
        ;; Tower_Base_Check_Edge, and only on forge does the v0.2.0 layout defect
        ;; appear. An intake_check-based probe reports RUNNABLE on a tarball that
        ;; cannot forge -- it was written that way first, and said PASS.
        out     (when door (speak doordir door
                                  [{:jsonrpc "2.0" :id 2 :method "tools/call"
                                    :params {:name "forge" :arguments {:sheet sheet}}}]))
        answers (boolean (and out (str/includes? out "serverInfo")))
        tower?  (boolean (and out (str/includes? out "tower_base_missing")))
        ;; The forge reply names the stage it reached. Reaching ANY pipeline
        ;; stage past the tower is the layout working; WHICH stage it refuses at
        ;; is about the sheet, not the packaging, and is not this probe's business.
        ;; (A single expression-function sheet legitimately refuses at prove_body:
        ;; a spec-only unit has no body to fill. That is a product defect tracked
        ;; separately, not a packaging fault.)
        intake? (boolean (and out (str/includes? out "transitions")))
        facts   {:unpacked ok? :door-present (some? door) :door-answers answers
                 :base-found (not tower?) :reaches-intake (and intake? (not tower?))}
        v       (verdict facts)]
    (println (format "tarball: %s" tarball))
    (println (format "facts:   unpacked=%s door_present=%s door_answers=%s base_found=%s reaches_intake=%s\n"
                     (:unpacked facts) (:door-present facts) (:door-answers facts)
                     (:base-found facts) (:reaches-intake facts)))
    ;; ENVIRONMENT THE PROBE DID NOT PROVIDE. The factory's rails are loopback
    ;; services. On a developer's machine they are already up, and a PASS here is
    ;; flattered by that -- the first run of this probe said RUNNABLE while the
    ;; host happened to be serving all three. A stranger has none of them.
    (let [up (for [[port rail] [[11434 "model"] [8471 "prover"] [8472 "vacuity"]]
                   :let [open? (try (with-open [s (java.net.Socket.)]
                                      (.connect s (java.net.InetSocketAddress. "127.0.0.1" (int port)) 400)
                                      true)
                                    (catch Exception _ false))]]
               [port rail open?])]
      (println "  loopback rails this host was ALREADY serving (NOT provided by the tarball):")
      (doseq [[port rail open?] up]
        (println (format "    %-6s %-8s %s" port rail
                         (if open? "UP  -- a stranger would NOT have this" "down"))))
      (when (some (fn [[_ _ o]] o) up)
        (println "  ⚠ this run is not a clean-room result; re-run where these are down.")))
    (println)
    (when door
      (println (format "  door at: %s" (str/replace door scratch "<unpacked>")))
      (println (format "  layout : %s"
                       (str/join " " (sort (map fs/file-name (fs/list-dir doordir)))))))
    (println)
    (case v
      :runnable    (do (println "RUNNABLE: a stranger can unpack this and reach the intake.")
                       (fs/delete-tree scratch) (System/exit 0))
      :not-runnable (do (println "NOT RUNNABLE: a stranger cannot forge with this tarball.")
                        (when tower?
                          (println "  the door stopped at the tower: it reads tower/base.bundle relative to cwd.")
                          (println "  check the bundle is shipped AT tower/base.bundle, not flat at the top level."))
                        (println (format "  unpacked tree kept for inspection: %s" scratch))
                        (System/exit 1))
      :unpackable  (do (println "COULD NOT UNPACK the tarball.") (System/exit 2)))))
