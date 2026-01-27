
(define-trait share-token-trait
  (
    ;; SIP-010 functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))

    ;; Governance specific functions
    (lock-shares (principal uint) (response bool uint))
    (unlock-shares (principal uint) (response bool uint))
    
    ;; Whitelist check function
    (check-whitelisted (principal) (response bool uint))
  )
)
