#!/usr/bin/env bb
;; crucible-launch.bb -- start the factory, and stop what it started.
;;
;; Ruled 2026-09-19 (decision_release_install_hybrid_2026_09_19): the stand needs
;; "a launcher wrapper for the cwd-relative rail.conf". This is that wrapper.
;;
;; WHY IT IS NEEDED. The door resolves `config/rail.conf` and `tower/base.bundle`
;; RELATIVE TO THE DIRECTORY IT IS STARTED IN. Started anywhere else it refuses
;; every forge with `tower_base_missing` and a hint that points at the wrong
;; thing. CONNECTING.md already works around this by hand:
;;     claude mcp add crucible -- sh -c 'cd /absolute/path && exec bin/crucible-agpl'
;; The user should not have to know that. This launcher knows it instead.
;;
;; It also starts the rails the door needs and STOPS THEM AFTERWARDS. Today a
;; stranger downloads four binaries and is left to run three of them; whatever it
;; starts, it cleans up, so nothing is left listening after the door exits.
;;
;; NOT AN INSTALLER. It installs nothing, downloads nothing, writes no config and
;; touches nothing outside this directory. If the install is not ready it says so
;; and refuses -- run tools/factory-doctor.bb to see why. (The ruling is explicit:
;; read-only factory.doctor, no factory.install.)
;;
;; ⚠ INTERIM, AND MEANT TO DIE. Tony ruled 2026-09-23: "I want crucible as one
;; exec". When the prover and vacuity rails are subsumed into the door -- spawning
;; gnatprove directly, as reef_relay_main already spawns curl -- nothing will
;; listen and this launcher will have nothing left to start. Delete it then.
;;
;; Usage:  bb tools/crucible-launch.bb            # serve the door on stdio
;;         bb tools/crucible-launch.bb --check    # start rails, report, stop
;; Exit:   the door's exit code · 1 install not ready · 2 no factory here

(require '[clojure.string :as str]
         '[babashka.fs :as fs]
         '[babashka.process :as p])

(def root (str (fs/absolutize (fs/parent (fs/parent *file*)))))

(defn- port-open? [port]
  (try (with-open [s (java.net.Socket.)]
         (.connect s (java.net.InetSocketAddress. "127.0.0.1" (int port)) 400) true)
       (catch Exception _ false)))

(defn- rail-port [conf name]
  (when (fs/exists? conf)
    (some (fn [line]
            (when (re-find (re-pattern (str "\"rail\":\"" name "\"")) line)
              (some-> (second (re-find #"\"port\":\"([^\"]+)\"" line)) parse-long)))
          (str/split-lines (slurp conf)))))

(defn- find-exe [& names]
  (first (filter fs/exists? (mapcat (fn [n] [(fs/file root "bin" n) (fs/file root n)]) names))))

(let [args   (set *command-line-args*)
      check? (contains? args "--check")
      door   (find-exe "crucible-agpl" "crucible-commercial")
      base   (fs/file root "tower/base.bundle")
      conf   (fs/file root "config/rail.conf")]

  (when-not door
    (binding [*out* *err*] (println "no crucible door in" root))
    (System/exit 2))

  ;; Refuse rather than repair. Repairing here would hide the packaging defect
  ;; that put us in this position -- every machine we own was already set up,
  ;; which is exactly why nobody saw that the release ships no tower/ directory.
  (when-not (and (fs/exists? base) (fs/exists? conf))
    (binding [*out* *err*]
      (println "this install is not ready:")
      (when-not (fs/exists? base) (println "  missing tower/base.bundle"))
      (when-not (fs/exists? conf) (println "  missing config/rail.conf"))
      (println "run: bb tools/factory-doctor.bb" root))
    (System/exit 1))

  (let [started (atom [])
        stop!   (fn []
                  (doseq [{:keys [name proc]} @started]
                    (binding [*out* *err*] (println "stopping" name))
                    (try (p/destroy-tree proc) (catch Exception _ nil))))]
    (.addShutdownHook (Runtime/getRuntime) (Thread. stop!))

    ;; Start only rails that are DECLARED, not already up, and whose binary we ship.
    ;; The reef relay is one of them (Tony, 2026-09-23): a fresh install must reach the tower
    ;; automatically, so the relay is started here beside prover and vacuity.
    (doseq [[rail exe] [["prover" "prover_service_main"] ["vacuity" "vacuity_service_main"] ["reef" "reef_relay_main"]]]
      (let [port (rail-port conf rail)
            bin  (find-exe exe)]
        (cond
          (nil? port) (binding [*out* *err*] (println (format "no %s rail declared; not starting one" rail)))
          (port-open? port) (binding [*out* *err*] (println (format "%s rail already up on %s; leaving it alone" rail port)))
          (nil? bin) (binding [*out* *err*] (println (format "%s rail declared on %s but no %s shipped here" rail port exe)))
          :else (do (binding [*out* *err*] (println (format "starting %s on %s" rail port)))
                    (swap! started conj {:name rail
                                         :proc (p/process {:dir root :out :inherit :err :inherit}
                                                          (str bin))})))))

    ;; The model rail is the user's own and is never started here: Crucible ships
    ;; no model, by design.
    (let [mp (or (rail-port conf "model") (rail-port conf "ollama"))]
      (when (and mp (not (port-open? mp)))
        (binding [*out* *err*]
          (println (format "model rail declared on %s but nothing is answering there." mp))
          (println "Crucible ships no model. Point the model line at the endpoint you run."))))

    (if check?
      (do (Thread/sleep 800)
          (binding [*out* *err*]
            (doseq [[rail] [["prover"] ["vacuity"]]]
              (when-let [port (rail-port conf rail)]
                (println (format "  %-8s %s %s" rail port (if (port-open? port) "up" "DOWN"))))))
          (stop!)
          (System/exit 0))
      ;; Serve the door on stdio from the factory directory -- the whole point.
      (let [proc (p/process {:dir root :in :inherit :out :inherit :err :inherit} (str door))
            code (:exit @proc)]
        (stop!)
        (System/exit code)))))
