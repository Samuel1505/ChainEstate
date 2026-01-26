;; Property Registry Contract
;; Master NFT contract - each property is a unique NFT representing legal ownership

(impl-trait .sip-009-nft-trait.nft-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PROPERTY-NOT-FOUND (err u201))
(define-constant ERR-PROPERTY-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-STATUS (err u203))
(define-constant ERR-INVALID-PROPERTY-ID (err u204))

;; Property status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-MAINTENANCE u2)
(define-constant STATUS-FORECLOSURE u3)

;; NFT definition
(define-non-fungible-token property uint)

;; Data variables
(define-data-var last-property-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Property data structure
(define-map properties
  uint
  {
    property-address: (string-ascii 256),
    total-value: uint,
    total-shares: uint,
    share-token-contract: (optional principal),
    property-manager: principal,
    creation-date: uint,
    status: uint,
    metadata-uri: (string-ascii 256),
    legal-entity: principal
  }
)

;; Helper functions

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-property-manager-for (property-id uint))
  (match (map-get? properties property-id)
    prop-data (is-eq tx-sender (get property-manager prop-data))
    false
  )
)

(define-private (is-valid-status (status uint))
  (or 
    (is-eq status STATUS-ACTIVE)
    (or
      (is-eq status STATUS-MAINTENANCE)
      (is-eq status STATUS-FORECLOSURE)
    )
  )
)

;; Read-only functions

(define-read-only (get-last-token-id)
  (ok (var-get last-property-id))
)

(define-read-only (get-token-uri (property-id uint))
  (ok (some (get metadata-uri (unwrap! (map-get? properties property-id) (err u404)))))
)

(define-read-only (get-owner (property-id uint))
  (ok (nft-get-owner? property property-id))
)

(define-read-only (get-property-details (property-id uint))
  (ok (map-get? properties property-id))
)

(define-read-only (get-property-status (property-id uint))
  (ok (get status (unwrap! (map-get? properties property-id) (err u404))))
)

(define-read-only (get-property-manager (property-id uint))
  (ok (get property-manager (unwrap! (map-get? properties property-id) (err u404))))
)

(define-read-only (get-share-token-contract (property-id uint))
  (ok (get share-token-contract (unwrap! (map-get? properties property-id) (err u404))))
)

;; Public functions

(define-public (create-property 
    (property-address (string-ascii 256))
    (total-value uint)
    (total-shares uint)
    (property-manager principal)
    (metadata-uri (string-ascii 256))
    (legal-entity principal)
  )
  (let
    (
      (new-property-id (+ (var-get last-property-id) u1))
    )
    ;; Only contract owner can create properties
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Mint property NFT to contract (will be transferred after setup)
    (try! (nft-mint? property new-property-id tx-sender))
    
    ;; Store property data
    (map-set properties new-property-id {
      property-address: property-address,
      total-value: total-value,
      total-shares: total-shares,
      share-token-contract: none,
      property-manager: property-manager,
      creation-date: stacks-block-height,
      status: STATUS-ACTIVE,
      metadata-uri: metadata-uri,
      legal-entity: legal-entity
    })
    
    ;; Update last property ID
    (var-set last-property-id new-property-id)
    
    ;; Print event for indexing
    (print {
      event: "property-created",
      property-id: new-property-id,
      property-address: property-address,
      total-value: total-value,
      total-shares: total-shares,
      property-manager: property-manager,
      legal-entity: legal-entity
    })
    
    (ok new-property-id)
  )
)

(define-public (set-share-token-contract (property-id uint) (token-contract principal))
  (let
    (
      (prop-data (unwrap! (map-get? properties property-id) ERR-PROPERTY-NOT-FOUND))
    )
    ;; Only contract owner can set share token contract
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Update property with share token contract
    (map-set properties property-id (merge prop-data { share-token-contract: (some token-contract) }))
    
    (print {
      event: "share-token-linked",
      property-id: property-id,
      token-contract: token-contract
    })
    
    (ok true)
  )
)

(define-public (update-property-status (property-id uint) (new-status uint))
  (let
    (
      (prop-data (unwrap! (map-get? properties property-id) ERR-PROPERTY-NOT-FOUND))
    )
    ;; Only contract owner or property manager can update status
    (asserts! (or (is-contract-owner) (is-property-manager-for property-id)) ERR-NOT-AUTHORIZED)
    
    ;; Validate status
    (asserts! (is-valid-status new-status) ERR-INVALID-STATUS)
    
    ;; Update status
    (map-set properties property-id (merge prop-data { status: new-status }))
    
    (print {
      event: "property-status-updated",
      property-id: property-id,
      old-status: (get status prop-data),
      new-status: new-status
    })
    
    (ok true)
  )
)

(define-public (set-property-manager (property-id uint) (new-manager principal))
  (let
    (
      (prop-data (unwrap! (map-get? properties property-id) ERR-PROPERTY-NOT-FOUND))
    )
    ;; Only contract owner can change property manager
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Update property manager
    (map-set properties property-id (merge prop-data { property-manager: new-manager }))
    
    (print {
      event: "property-manager-changed",
      property-id: property-id,
      old-manager: (get property-manager prop-data),
      new-manager: new-manager
    })
    
    (ok true)
  )
)

(define-public (transfer (property-id uint) (sender principal) (recipient principal))
  (begin
    ;; Check ownership
    (asserts! (is-eq sender (unwrap! (nft-get-owner? property property-id) ERR-PROPERTY-NOT-FOUND)) ERR-NOT-AUTHORIZED)
    
    ;; Only owner can transfer
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    
    ;; Transfer NFT
    (try! (nft-transfer? property property-id sender recipient))
    
    (print {
      event: "property-transferred",
      property-id: property-id,
      from: sender,
      to: recipient
    })
    
    (ok true)
  )
)

;; SIP-009 required functions
(define-public (transfer-memo (property-id uint) (sender principal) (recipient principal) (memo (buff 34)))
  (begin
    (try! (transfer property-id sender recipient))
    (print memo)
    (ok true)
  )
)
