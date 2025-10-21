;; Infra Peak Utils - Temporal Infrastructure Protocol
;; Decentralized timestamp verification system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-validator (err u101))
(define-constant err-insufficient-stake (err u102))
(define-constant err-timestamp-exists (err u103))
(define-constant err-invalid-timestamp (err u104))
(define-constant err-validator-exists (err u105))

;; Minimum stake required to become a validator (1000 tokens)
(define-constant min-validator-stake u1000000000)

;; Data Variables
(define-data-var total-timestamps uint u0)
(define-data-var total-validators uint u0)

;; Data Maps
(define-map validators
    principal
    {
        stake: uint,
        registered-at: uint,
        active: bool,
        timestamp-count: uint
    }
)

(define-map timestamps
    uint
    {
        hash: (buff 32),
        block-height: uint,
        validator: principal,
        metadata: (string-ascii 256),
        verified: bool,
        created-at: uint
    }
)

(define-map timestamp-lookup
    (buff 32)
    uint
)

;; Validator Management Functions

(define-public (register-validator (stake-amount uint))
    (let
        (
            (sender tx-sender)
        )
        (asserts! (>= stake-amount min-validator-stake) err-insufficient-stake)
        (asserts! (is-none (map-get? validators sender)) err-validator-exists)
        
        (map-set validators sender {
            stake: stake-amount,
            registered-at: block-height,
            active: true,
            timestamp-count: u0
        })
        
        (var-set total-validators (+ (var-get total-validators) u1))
        (ok true)
    )
)

(define-public (deactivate-validator)
    (let
        (
            (sender tx-sender)
            (validator-data (unwrap! (map-get? validators sender) err-not-validator))
        )
        (map-set validators sender (merge validator-data { active: false }))
        (ok true)
    )
)

;; Timestamp Creation Functions

(define-public (create-timestamp (data-hash (buff 32)) (metadata (string-ascii 256)))
    (let
        (
            (sender tx-sender)
            (validator-data (unwrap! (map-get? validators sender) err-not-validator))
            (timestamp-id (+ (var-get total-timestamps) u1))
        )
        (asserts! (get active validator-data) err-not-validator)
        (asserts! (is-none (map-get? timestamp-lookup data-hash)) err-timestamp-exists)
        
        (map-set timestamps timestamp-id {
            hash: data-hash,
            block-height: block-height,
            validator: sender,
            metadata: metadata,
            verified: true,
            created-at: block-height
        })
        
        (map-set timestamp-lookup data-hash timestamp-id)
        
        (map-set validators sender 
            (merge validator-data { 
                timestamp-count: (+ (get timestamp-count validator-data) u1) 
            })
        )
        
        (var-set total-timestamps timestamp-id)
        (ok timestamp-id)
    )
)

;; Verification Functions

(define-read-only (verify-timestamp (data-hash (buff 32)))
    (match (map-get? timestamp-lookup data-hash)
        timestamp-id (match (map-get? timestamps timestamp-id)
            timestamp-data (ok {
                verified: (get verified timestamp-data),
                block-height: (get block-height timestamp-data),
                validator: (get validator timestamp-data),
                timestamp-id: timestamp-id
            })
            (err err-invalid-timestamp)
        )
        (err err-invalid-timestamp)
    )
)

(define-read-only (get-timestamp (timestamp-id uint))
    (ok (map-get? timestamps timestamp-id))
)

(define-read-only (get-timestamp-by-hash (data-hash (buff 32)))
    (match (map-get? timestamp-lookup data-hash)
        timestamp-id (ok (map-get? timestamps timestamp-id))
        (ok none)
    )
)

;; Validator Query Functions

(define-read-only (get-validator-info (validator principal))
    (ok (map-get? validators validator))
)

(define-read-only (is-active-validator (validator principal))
    (match (map-get? validators validator)
        validator-data (ok (get active validator-data))
        (ok false)
    )
)

;; Statistics Functions

(define-read-only (get-total-timestamps)
    (ok (var-get total-timestamps))
)

(define-read-only (get-total-validators)
    (ok (var-get total-validators))
)

(define-read-only (get-validator-timestamp-count (validator principal))
    (match (map-get? validators validator)
        validator-data (ok (get timestamp-count validator-data))
        (ok u0)
    )
)