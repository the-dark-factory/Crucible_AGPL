#!/usr/bin/env bb
;; factory-doctor.bb -- READ-ONLY diagnosis of a Crucible install.
;;
;; Ruled 2026-09-19 (decision_release_install_hybrid_2026_09_19): a stranger
;; installs via the HYBRID -- "the stand" (a factory-built local installer) plus
;; a Claude Code skill that drives it, plus a READ-ONLY `factory.doctor`. There
;; is deliberately NO `factory.install`: an MCP server cannot install itself,
;; because the door exists only after the install and the sole-door rule forbids
;; it touching the host. This is that doctor.
;;
;; IT CHANGES NOTHING. It creates no directory, writes no config, starts no
;; service. It looks, and it names what is wrong and what would fix it. An
;; agent driving the install reads this and acts; the doctor never acts.
;;
;; Why it exists: v0.2.0 shipped `base.bundle` flat while the door reads
;; `tower/base.bundle` relative to its start directory, so every forge by every
;; stranger refused with `tower_base_missing` and a hint that pointed at the
;; wrong thing. Nobody saw it because every machine we own was already set up.
;;
;; ---------------------------------------------------------------------------
;; SHAPE: written to be LOVELACED. The decision is PURE (candidate core:
;; Install_Health_Pkg): measured facts in, one verdict out. The edge looks.
;;   door_present, base_in_place, rail_conf_present,
;;   model_rail_declared, model_rail_up,
;;   prover_rail_declared, prover_rail_up,
;;   prover_binary_present, gnatprove_on_path       (all Boolean)
;; Theorems:
;;   READY-IFF-DOOR-AND-BASE-AND-RAILS   Ready <=> door_present and
;;     base_in_place and rail_conf_present and model_rail_up and prover_rail_up
;;   NO-BASE-IS-NEVER-READY   (the v0.2.0 defect, named as a theorem)
;;   A-DECLARED-RAIL-THAT-IS-DOWN-IS-NOT-READY
;;   TOTAL
;; ---------------------------------------------------------------------------
;;
;; Usage: bb tools/factory-doctor.bb [install-dir]   (default: cwd)
;; Exit:  0 ready · 1 not ready (findings printed) · 2 no factory here

(require '[clojure.string :as str]
         '[babashka.fs :as fs])

;; === THE DECISION -- pure; becomes Install_Health_Pkg =====================

(defn verdict
  [{:keys [door-present base-in-place rail-conf-present model-rail-up prover-rail-up]}]
  (cond
    (not door-present)      :no-factory
    (not base-in-place)     :not-ready
    (not rail-conf-present) :not-ready
    (not model-rail-up)     :not-ready
    (not prover-rail-up)    :not-ready
    :else                   :ready))

;; === THE EDGE -- looks only; changes nothing ==============================

(defn- port-open? [port]
  (try (with-open [s (java.net.Socket.)]
         (.connect s (java.net.InetSocketAddress. "127.0.0.1" (int port)) 400) true)
       (catch Exception _ false)))

(defn- on-path? [exe]
  (some #(fs/exists? (fs/file % exe))
        (str/split (or (System/getenv "PATH") "") #":")))

(defn- rails [conf]
  (if (fs/exists? conf)
    (for [line (str/split-lines (slurp conf))
          :when (str/includes? line "\"rail\"")
          :let [rail (second (re-find #"\"rail\":\"([^\"]+)\"" line))
                port (second (re-find #"\"port\":\"([^\"]+)\"" line))]]
      {:rail rail :port (when port (parse-long port))})
    []))

(let [root  (or (first *command-line-args*) ".")
      door  (first (filter fs/exists? (map #(fs/file root %)
                                           ["bin/crucible-agpl" "crucible-agpl"
                                            "bin/crucible-commercial" "crucible-commercial"])))
      base  (fs/file root "tower/base.bundle")
      flat  (fs/file root "base.bundle")
      conf  (fs/file root "config/rail.conf")
      rs    (rails conf)
      by    (fn [n] (first (filter #(= n (:rail %)) rs)))
      model (or (by "model") (by "ollama"))
      prov  (by "prover")
      facts {:door-present         (some? door)
             :base-in-place        (fs/exists? base)
             :rail-conf-present    (fs/exists? conf)
             :model-rail-declared  (some? model)
             :model-rail-up        (boolean (and model (port-open? (:port model))))
             :prover-rail-declared (some? prov)
             :prover-rail-up       (boolean (and prov (port-open? (:port prov))))
             :prover-binary-present (boolean (first (filter fs/exists?
                                                            (map #(fs/file root %)
                                                                 ["bin/prover_service_main" "prover_service_main"]))))
             :gnatprove-on-path    (boolean (on-path? "gnatprove"))}
      v     (verdict facts)
      findings (cond-> []
                 (and (not (:base-in-place facts)) (fs/exists? flat))
                 (conj ["base.bundle is at the top level, not at tower/base.bundle"
                        "the door reads tower/base.bundle relative to where it is STARTED. Move it: mkdir tower && mv base.bundle tower/"])
                 (and (not (:base-in-place facts)) (not (fs/exists? flat)))
                 (conj ["no base bundle anywhere in this install"
                        "the door refuses every forge without it. Re-download the release."])
                 (not (:rail-conf-present facts))
                 (conj ["config/rail.conf is missing"
                        "the door reads it relative to where it is STARTED. Without it nothing is sent."])
                 (and (:rail-conf-present facts) (not (:model-rail-declared facts)))
                 (conj ["no model rail declared in config/rail.conf"
                        "add a model line naming the endpoint you will use. Crucible ships no model."])
                 (and (:model-rail-declared facts) (not (:model-rail-up facts)))
                 (conj [(format "model rail declared on port %s but nothing is answering" (:port model))
                        "start your model there, or point the model line at the endpoint you actually run."])
                 (and (:prover-rail-declared facts) (not (:prover-rail-up facts)))
                 (conj [(format "prover rail declared on port %s but nothing is answering" (:port prov))
                        (if (:prover-binary-present facts)
                          "start the prover service shipped beside the door, from this directory."
                          "no prover service binary found in this install.")])
                 (not (:gnatprove-on-path facts))
                 (conj ["gnatprove is not on PATH"
                        "the proof toolchain is fetched with the pinned Alire recipe; see INSTALL.md."])
                 ;; 2026-09-23: found by testing the shipped tarball rather than the
                 ;; dev tree. The prover service refuses to start without its own
                 ;; config, and the config CANNOT ship fully-formed because the
                 ;; gnatprove path is machine-specific. A bare "gnatprove" is NOT
                 ;; resolved from PATH -- it must be an absolute path. Without this
                 ;; service nothing proves, which is the whole product.
                 (not (fs/exists? (fs/file root "config/prover-service.conf")))
                 (conj ["config/prover-service.conf is missing — the prover service will not start"
                        (str "write it with YOUR absolute gnatprove path (a bare name is not resolved from PATH):\n"
                             "      {\"port\":\"8471\",\"staging_root\":\"state/prover-staging\","
                             "\"gnatprove\":\""
                             (or (some #(let [f (fs/file % "gnatprove")]
                                          (when (fs/exists? f) (str f)))
                                       (str/split (or (System/getenv "PATH") "") #":"))
                                 "/absolute/path/to/gnatprove")
                             "\",\"timeout_seconds\":\"600\"}")])
                 (not (fs/exists? (fs/file root "config/vacuity-service.conf")))
                 (conj ["config/vacuity-service.conf is missing — the vacuity rail will not start"
                        "it needs a battery binary that is NOT shipped in the release; the vacuity rail is unavailable without it."]))]
  (println (format "factory: %s" (str (fs/absolutize root))))
  (println (format "door   : %s\n" (if door (str (fs/file-name door)) "NOT FOUND")))
  (doseq [[k label] [[:base-in-place "tower/base.bundle"] [:rail-conf-present "config/rail.conf"]
                     [:model-rail-up "model rail"] [:prover-rail-up "prover rail"]
                     [:gnatprove-on-path "gnatprove on PATH"]]]
    (println (format "  %-4s %s" (if (get facts k) "ok" "--") label)))
  (when (seq findings)
    (println "\nfindings:")
    (doseq [[what fix] findings]
      (println (format "  * %s\n      %s" what fix))))
  (println)
  ;; A finding is by definition something standing between this install and a
  ;; forge, so findings DEMOTE the verdict. Without this the doctor said READY
  ;; on a tarball whose prover service could not start, because the HOST's own
  ;; prover was answering on 8471 -- the same flattery that let the broken
  ;; release ship.
  (let [v (if (and (= v :ready) (seq findings)) :not-ready v)]
  (case v
    :ready      (do (println "READY: this install can forge.") (System/exit 0))
    :not-ready  (do (println "NOT READY: the findings above are what stands between this install and a forge.")
                    (println "This doctor changes nothing. Apply the fixes yourself, or have your agent apply them.")
                    (System/exit 1))
    :no-factory (do (println "NO FACTORY HERE: no crucible door found in this directory.")
                    (System/exit 2)))))
