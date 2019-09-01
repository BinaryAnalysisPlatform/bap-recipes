(parameter depth 4096 "a depth of analysis")
(parameter entry-points all-subroutines "where to search")

(option primus-lisp-load
        posix
        check-deref)

(option api-path $prefix/api)

(option run)
(option run-entry-points ${entry-points})
(option constant-tracker-enable)

(option null-ptr-deref-enable)
(option with-no-return)
(option primus-lisp-add $prefix)
(option primus-promiscuous-mode)
(option primus-greedy-scheduler)
(option primus-limit-max-length $depth)
(option primus-print-output incidents)

(option primus-lisp-channel-redirect
  <stdin>:$prefix/stdin
  <stdout>:$prefix/stdout
  <stderr>:$prefix/stderr)

(option primus-print-observations
        pc-changed
        jumping
        call
        call-return
        enter-pos
        written
        loaded
        read
        stored
        lisp-message
        machine-switch
        machine-fork
        incident
        incident-location)

(option log-dir log)
