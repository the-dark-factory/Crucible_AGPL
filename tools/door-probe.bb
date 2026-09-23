#!/usr/bin/env bb
;; door-probe.bb -- every tool the door ADVERTISES must ANSWER.
;;
;; Why this exists: on 2026-09-23 `tools/list` advertised ten tools and the
;; dispatcher implemented five. palais.shelf/claim/fetch/attempt/submit returned
;; -32602 "unknown tool". Nothing caught it, because the door-is-sole mui COUNTS
;; tools and schemas and never CALLS them. This is the last-mile check.
;;
;; ---------------------------------------------------------------------------
;; SHAPE: this file is written to be LOVELACED -- the decision below becomes a
;; proven Ada core, and what remains here shrinks to the edge that measures.
;;
;;   THE DECISION (future core, candidate name Door_Honesty_Pkg) is PURE:
;;     measured facts in -> one verdict out. No I/O, no process, no clock,
;;     no state. It is the `verdict` function and nothing else.
;;
;;   THE EDGE (everything else here) spawns the binary, speaks JSON-RPC, and
;;     MEASURES three facts. It judges nothing. When the core is forged, this
;;     file keeps only the measuring and calls the core for the verdict.
;;
;;   The facts, fixed now so the core's contract does not drift:
;;     list_readable   Boolean  -- tools/list returned a tool array
;;     advertised      Natural  -- how many tools it listed
;;     answered        Natural  -- how many of those replied with anything that
;;                                is NOT a method/tool-not-found error
;;   Theorems the core must keep:
;;     HONEST-IFF-ALL-ANSWER   Honest <=> (list_readable and advertised > 0
;;                                         and answered = advertised)
;;     ANSWERED-NEVER-EXCEEDS  answered <= advertised
;;     UNREADABLE-IS-NOT-HONEST  not list_readable => verdict /= Honest
;;     EMPTY-DOOR-IS-NOT-HONEST  advertised = 0 => verdict /= Honest
;;     TOTAL                   every combination yields exactly one verdict
;; ---------------------------------------------------------------------------
;;
;; Usage:  bb tools/door-probe.bb [path-to-binary]
;;         (run from the crucible directory -- the door measures tower/base.bundle
;;          relative to cwd)
;; Exit:   0 Honest · 1 Over_Advertised · 2 Unreadable

(require '[babashka.process :as p]
         '[cheshire.core :as json]
         '[clojure.string :as str])

;; === THE DECISION -- pure; becomes Door_Honesty_Pkg ========================

(defn verdict
  "Measured facts in, one verdict out. Pure: no I/O, no state."
  [{:keys [list-readable advertised answered]}]
  (cond
    (not list-readable)        :unreadable
    (zero? advertised)         :over-advertised
    (= answered advertised)    :honest
    :else                      :over-advertised))

;; === THE EDGE -- measures only; judges nothing =============================

(def binary (or (first *command-line-args*) "./bin/crucible-agpl"))
(def not-found #{-32601 -32602})

(defn- speak [requests]
  (let [preamble [{:jsonrpc "2.0" :id 1 :method "initialize" :params {}}
                  {:jsonrpc "2.0" :method "notifications/initialized"}]
        input    (str/join "\n" (map json/generate-string (concat preamble requests)))
        {:keys [out]} (p/shell {:in (str input "\n") :out :string :err :string
                                :continue true}
                               binary)]
    (->> (str/split-lines out) (remove str/blank?)
         (map #(json/parse-string % true)))))

(defn- measure-advertised []
  (let [r (->> (speak [{:jsonrpc "2.0" :id 2 :method "tools/list" :params {}}])
               (filter #(= 2 (:id %))) first)]
    (when-not (:error r) (mapv :name (get-in r [:result :tools])))))

(defn- measure-answers [names]
  (let [ids   (into {} (map-indexed (fn [i t] [(+ 100 i) t]) names))
        reqs  (for [[id t] (sort ids)]
                {:jsonrpc "2.0" :id id :method "tools/call"
                 :params {:name t :arguments {}}})
        rs    (into {} (for [r (speak (vec reqs)) :when (:id r)] [(:id r) r]))]
    (for [[id t] (sort ids)
          :let [r (get rs id) code (get-in r [:error :code])]]
      {:tool t
       :answered? (boolean (and r (not (and code (not-found code)))))
       :note (cond (nil? r) "no reply at all"
                   (and code (not-found code)) (format "%d %s" code (get-in r [:error :message]))
                   code (format "error %d (counts as answering)" code)
                   :else "answered")})))

(let [names   (measure-advertised)
      results (when names (measure-answers names))
      facts   {:list-readable (some? names)
               :advertised    (count names)
               :answered      (count (filter :answered? results))}
      v       (verdict facts)]
  (println (format "door: %s" binary))
  (println (format "facts: list_readable=%s advertised=%d answered=%d\n"
                   (:list-readable facts) (:advertised facts) (:answered facts)))
  (doseq [{:keys [tool answered? note]} results]
    (println (format "  %-7s %-16s %s" (if answered? "answers" "DEAD") tool note)))
  (println)
  (case v
    :honest          (do (println (format "PASSED (Honest): all %d advertised tool(s) answer."
                                          (:advertised facts)))
                         (System/exit 0))
    :over-advertised (let [dead (map :tool (remove :answered? results))]
                       (println (format "REFUSED (Over_Advertised): %d of %d advertised tool(s) do not answer: %s"
                                        (count dead) (:advertised facts) (str/join ", " dead)))
                       (println "A door that lists a tool it cannot run fails the first stranger who tries it.")
                       (System/exit 1))
    :unreadable      (do (println "REFUSED (Unreadable): tools/list did not return a tool array.")
                         (System/exit 2))))
