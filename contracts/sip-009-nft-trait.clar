;; SIP-009 NFT Trait
;; Standard trait for non-fungible tokens on Stacks blockchain

(define-trait nft-trait
  (
    ;; Get the last minted token ID
    (get-last-token-id () (response uint uint))
    
    ;; Get token URI for metadata
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    
    ;; Get owner of a token
    (get-owner (uint) (response (optional principal) uint))
    
    ;; Transfer token
    (transfer (uint principal principal) (response bool uint))
  )
)
