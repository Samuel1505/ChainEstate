;; Share Token Contract
;; SIP-010 Fungible Token for fractional property ownership
;; Each property has its own instance of this contract

(impl-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-NOT-WHITELISTED (err u301))
(define-constant ERR-SHARES-LOCKED (err u302))
(define-constant ERR-INSUFFICIENT-BALANCE (err u303))
(define-constant ERR-BELOW-MINIMUM (err u304))
(define-constant ERR-ALREADY-INITIALIZED (err u305))

;; Token constants (set during initialization)
(define-data-var token-name (string-ascii 32) "")
(define-data-var token-symbol (string-ascii 32) "")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Property reference
(define-data-var property-id uint u0)
(define-data-var property-registry principal tx-sender)

;; Token economics
(define-data-var total-supply uint u0)
(define-data-var min-investment uint u100000000) ;; 0.1 share (with 6 decimals)

;; Contract state
(define-data-var initialized bool false)
(define-data-var access-control-contract principal tx-sender)

;; Balances
(define-map balances principal uint)

;; Whitelist for KYC compliance
(define-map whitelist principal bool)

;; Share locks (for governance voting)
(define-map locked-shares principal uint)

;; Helper functions

(define-private (is-admin)
  (contract-call? .access-control is-admin tx-sender)
)

(define-private (is-whitelisted (address principal))
  (default-to false (map-get? whitelist address))
)

(define-private (get-locked-amount (address principal))
  (default-to u0 (map-get? locked-shares address))
)

(define-private (get-available-balance (address principal))
  (let
    (
      (total-balance (unwrap-panic (get-balance address)))
      (locked (get-locked-amount address))
    )
    (- total-balance locked)
  )
)

;; Read-only functions (SIP-010 compliance)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (map-get? balances account)))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Additional read-only functions

(define-read-only (get-property-id)
  (ok (var-get property-id))
)

(define-read-only (get-locked-balance (account principal))
  (ok (get-locked-amount account))
)

(define-read-only (get-available-balance-of (account principal))
  (ok (get-available-balance account))
)

(define-read-only (is-address-whitelisted (address principal))
  (ok (is-whitelisted address))
)

;; Public functions

(define-public (initialize
    (name (string-ascii 32))
    (symbol (string-ascii 32))
    (prop-id uint)
    (total-shares uint)
    (uri (optional (string-utf8 256)))
    (access-control principal)
  )
  (begin
    ;; Can only initialize once
    (asserts! (not (var-get initialized)) ERR-ALREADY-INITIALIZED)
    
    ;; Only admin can initialize
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    ;; Set token metadata
    (var-set token-name name)
    (var-set token-symbol symbol)
    (var-set token-uri uri)
    (var-set property-id prop-id)
    (var-set access-control-contract access-control)
    
    ;; Calculate total supply (shares * 10^6 for decimals)
    (let
      (
        (supply (* total-shares u1000000))
      )
      (var-set total-supply supply)
      
      ;; Mint all shares to contract deployer (platform treasury)
      (map-set balances tx-sender supply)
      
      ;; Whitelist platform treasury
      (map-set whitelist tx-sender true)
    )
    
    ;; Mark as initialized
    (var-set initialized true)
    
    (print {
      event: "token-initialized",
      property-id: prop-id,
      name: name,
      symbol: symbol,
      total-supply: (var-get total-supply)
    })
    
    (ok true)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; Verify sender is tx-sender
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    
    ;; Check recipient is whitelisted (KYC compliance)
    (asserts! (is-whitelisted recipient) ERR-NOT-WHITELISTED)
    
    ;; Check sender has sufficient available balance (not locked)
    (asserts! (>= (get-available-balance sender) amount) ERR-SHARES-LOCKED)
    
    ;; Check minimum investment amount
    (asserts! (>= amount (var-get min-investment)) ERR-BELOW-MINIMUM)
    
    ;; Get balances
    (let
      (
        (sender-balance (unwrap-panic (get-balance sender)))
        (recipient-balance (unwrap-panic (get-balance recipient)))
      )
      ;; Update balances
      (map-set balances sender (- sender-balance amount))
      (map-set balances recipient (+ recipient-balance amount))
      
      (print {
        event: "transfer",
        sender: sender,
        recipient: recipient,
        amount: amount,
        memo: memo
      })
      
      (ok true)
    )
  )
)

(define-public (add-to-whitelist (address principal))
  (begin
    ;; Only KYC verifier or admin can whitelist
    (asserts! (or (is-admin) (contract-call? .access-control is-kyc-verifier tx-sender)) ERR-NOT-AUTHORIZED)
    
    (map-set whitelist address true)
    
    (print {
      event: "address-whitelisted",
      address: address
    })
    
    (ok true)
  )
)

(define-public (remove-from-whitelist (address principal))
  (begin
    ;; Only admin can remove from whitelist
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    (map-delete whitelist address)
    
    (print {
      event: "address-removed-from-whitelist",
      address: address
    })
    
    (ok true)
  )
)

(define-public (lock-shares (address principal) (amount uint))
  (let
    (
      (current-locked (get-locked-amount address))
      (available (get-available-balance address))
    )
    ;; Only governance contract can lock shares
    (asserts! (is-eq tx-sender (var-get access-control-contract)) ERR-NOT-AUTHORIZED)
    
    ;; Check sufficient available balance
    (asserts! (>= available amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update locked amount
    (map-set locked-shares address (+ current-locked amount))
    
    (print {
      event: "shares-locked",
      address: address,
      amount: amount,
      total-locked: (+ current-locked amount)
    })
    
    (ok true)
  )
)

(define-public (unlock-shares (address principal) (amount uint))
  (let
    (
      (current-locked (get-locked-amount address))
    )
    ;; Only governance contract can unlock shares
    (asserts! (is-eq tx-sender (var-get access-control-contract)) ERR-NOT-AUTHORIZED)
    
    ;; Check sufficient locked balance
    (asserts! (>= current-locked amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update locked amount
    (map-set locked-shares address (- current-locked amount))
    
    (print {
      event: "shares-unlocked",
      address: address,
      amount: amount,
      total-locked: (- current-locked amount)
    })
    
    (ok true)
  )
)

(define-public (burn (amount uint))
  (let
    (
      (sender-balance (unwrap-panic (get-balance tx-sender)))
      (current-supply (var-get total-supply))
    )
    ;; Only admin can burn (during property sale/foreclosure)
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    ;; Check sufficient balance
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update balance and supply
    (map-set balances tx-sender (- sender-balance amount))
    (var-set total-supply (- current-supply amount))
    
    (print {
      event: "shares-burned",
      amount: amount,
      new-total-supply: (- current-supply amount)
    })
    
    (ok true)
  )
)

(define-public (set-minimum-investment (new-minimum uint))
  (begin
    ;; Only admin can update minimum
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    (var-set min-investment new-minimum)
    
    (ok true)
  )
)
