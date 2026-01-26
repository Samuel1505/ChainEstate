;; Rental Distribution Contract
;; Automates monthly rental income distribution to shareholders

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-PROPERTY-NOT-FOUND (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-NOTHING-TO-CLAIM (err u403))
(define-constant ERR-INVALID-PERIOD (err u404))
(define-constant ERR-ALREADY-DEPOSITED (err u405))

;; Fee percentages (in basis points: 800 = 8%)
(define-data-var management-fee-bps uint u800)    ;; 8%
(define-data-var platform-fee-bps uint u200)      ;; 2%
(define-data-var maintenance-reserve-bps uint u500) ;; 5%

;; Contract references
(define-data-var access-control-contract principal tx-sender)

;; Distribution tracking
;; Key: { property-id, year, month }
(define-map rental-deposits
  { property-id: uint, year: uint, month: uint }
  {
    gross-income: uint,
    management-fee: uint,
    platform-fee: uint,
    maintenance-reserve: uint,
    net-distributable: uint,
    deposited-by: principal,
    deposit-height: uint
  }
)

;; Claim tracking
;; Key: { property-id, year, month, investor }
(define-map claims
  { property-id: uint, year: uint, month: uint, investor: principal }
  {
    amount-claimed: uint,
    claim-height: uint
  }
)

;; Total claimed per period
(define-map total-claimed
  { property-id: uint, year: uint, month: uint }
  uint
)

;; Helper functions

(define-private (is-admin)
  (contract-call? .access-control is-admin tx-sender)
)

(define-private (is-property-manager)
  (contract-call? .access-control is-property-manager tx-sender)
)

(define-private (calculate-fee (amount uint) (fee-bps uint))
  (/ (* amount fee-bps) u10000)
)

(define-private (get-share-balance (token-contract principal) (investor principal))
  (unwrap-panic (contract-call? token-contract get-balance investor))
)

(define-private (get-total-shares (token-contract principal))
  (unwrap-panic (contract-call? token-contract get-total-supply))
)

;; Read-only functions

(define-read-only (get-fee-structure)
  (ok {
    management-fee-bps: (var-get management-fee-bps),
    platform-fee-bps: (var-get platform-fee-bps),
    maintenance-reserve-bps: (var-get maintenance-reserve-bps)
  })
)

(define-read-only (get-distribution-details (property-id uint) (year uint) (month uint))
  (ok (map-get? rental-deposits { property-id: property-id, year: year, month: month }))
)

(define-read-only (get-claim-details (property-id uint) (year uint) (month uint) (investor principal))
  (ok (map-get? claims { property-id: property-id, year: year, month: month, investor: investor }))
)

;; Public functions

(define-public (deposit-rental-income 
    (property-id uint)
    (year uint)
    (month uint)
    (gross-income uint)
  )
  (let
    (
      (management-fee (calculate-fee gross-income (var-get management-fee-bps)))
      (platform-fee (calculate-fee gross-income (var-get platform-fee-bps)))
      (maintenance-reserve (calculate-fee gross-income (var-get maintenance-reserve-bps)))
      (total-fees (+ management-fee (+ platform-fee maintenance-reserve)))
      (net-distributable (- gross-income total-fees))
    )
    ;; Only property manager can deposit
    (asserts! (is-property-manager) ERR-NOT-AUTHORIZED)
    
    ;; Validate amount
    (asserts! (> gross-income u0) ERR-INVALID-AMOUNT)
    
    ;; Check if already deposited for this period
    (asserts! (is-none (map-get? rental-deposits { property-id: property-id, year: year, month: month })) 
      ERR-ALREADY-DEPOSITED)
    
    ;; Transfer STX from property manager to contract
    (unwrap! (stx-transfer? gross-income tx-sender (as-contract tx-sender)) ERR-INVALID-AMOUNT)
    
    ;; Record deposit
    (map-set rental-deposits
      { property-id: property-id, year: year, month: month }
      {
        gross-income: gross-income,
        management-fee: management-fee,
        platform-fee: platform-fee,
        maintenance-reserve: maintenance-reserve,
        net-distributable: net-distributable,
        deposited-by: tx-sender,
        deposit-height: block-height
      }
    )
    
    ;; Initialize total claimed to 0
    (map-set total-claimed { property-id: property-id, year: year, month: month } u0)
    
    (print {
      event: "rental-income-deposited",
      property-id: property-id,
      year: year,
      month: month,
      gross-income: gross-income,
      net-distributable: net-distributable,
      fees: {
        management: management-fee,
        platform: platform-fee,
        maintenance: maintenance-reserve
      }
    })
    
    (ok true)
  )
)

(define-public (claim-rental-income
    (property-id uint)
    (year uint)
    (month uint)
    (share-token-contract principal)
  )
  (let
    (
      (deposit (unwrap! (map-get? rental-deposits { property-id: property-id, year: year, month: month }) 
        ERR-INVALID-PERIOD))
      (investor-shares (get-share-balance share-token-contract tx-sender))
      (total-shares (get-total-shares share-token-contract))
      (net-distributable (get net-distributable deposit))
      (investor-portion (/ (* net-distributable investor-shares) total-shares))
      (already-claimed (default-to u0 
        (get amount-claimed 
          (map-get? claims { property-id: property-id, year: year, month: month, investor: tx-sender })
        )
      ))
      (claimable (- investor-portion already-claimed))
    )
    ;; Check if there's anything to claim
    (asserts! (> claimable u0) ERR-NOTHING-TO-CLAIM)
    
    ;; Transfer STX from contract to investor
    (try! (as-contract (stx-transfer? claimable tx-sender tx-sender)))
    
    ;; Record claim
    (map-set claims
      { property-id: property-id, year: year, month: month, investor: tx-sender }
      {
        amount-claimed: investor-portion,
        claim-height: block-height
      }
    )
    
    ;; Update total claimed
    (let
      (
        (current-total (default-to u0 (map-get? total-claimed { property-id: property-id, year: year, month: month })))
      )
      (map-set total-claimed { property-id: property-id, year: year, month: month } (+ current-total claimable))
    )
    
    (print {
      event: "rental-income-claimed",
      property-id: property-id,
      year: year,
      month: month,
      investor: tx-sender,
      amount: claimable,
      investor-shares: investor-shares,
      total-shares: total-shares
    })
    
    (ok claimable)
  )
)

(define-public (set-fee-structure 
    (new-management-fee-bps uint)
    (new-platform-fee-bps uint)
    (new-maintenance-reserve-bps uint)
  )
  (begin
    ;; Only admin can update fees (or via governance)
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    ;; Validate total fees don't exceed 100%
    (asserts! (<= (+ new-management-fee-bps (+ new-platform-fee-bps new-maintenance-reserve-bps)) u10000) 
      ERR-INVALID-AMOUNT)
    
    (var-set management-fee-bps new-management-fee-bps)
    (var-set platform-fee-bps new-platform-fee-bps)
    (var-set maintenance-reserve-bps new-maintenance-reserve-bps)
    
    (print {
      event: "fee-structure-updated",
      management-fee-bps: new-management-fee-bps,
      platform-fee-bps: new-platform-fee-bps,
      maintenance-reserve-bps: new-maintenance-reserve-bps
    })
    
    (ok true)
  )
)

(define-public (withdraw-fees (fee-type (string-ascii 20)) (amount uint) (recipient principal))
  (begin
    ;; Only admin can withdraw fees
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    
    ;; Transfer fees
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (print {
      event: "fees-withdrawn",
      fee-type: fee-type,
      amount: amount,
      recipient: recipient
    })
    
    (ok true)
  )
)
