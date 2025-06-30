;; NeonLedger - Carbon Credit Verification and Trading Contract
;; This contract manages carbon offset verification and credit issuance

;; Define constants
(define-constant contract-admin tx-sender)
(define-constant err-admin-only (err u300))
(define-constant err-not-verified (err u301))
(define-constant err-already-verified (err u302))
(define-constant err-invalid-validator (err u303))
(define-constant err-invalid-offset (err u304))
(define-constant err-not-permitted (err u305))
(define-constant err-invalid-cost (err u306))
(define-constant err-invalid-threshold (err u307))
(define-constant err-invalid-description (err u308))
(define-constant err-invalid-justification (err u309))

;; Define data variables
(define-data-var verification-cost uint u2000) ;; Cost in microstacks for verification
(define-data-var minimum-offset uint u50) ;; Minimum carbon offset required (in tonnes CO2)
(define-data-var max-cost uint u2000000) ;; Maximum allowed verification cost
(define-data-var max-offset uint u500000) ;; Maximum allowed offset amount

;; Define data maps
(define-map verified-offsetters principal bool)
(define-map authorized-validators principal bool)
(define-map offsetter-carbon-data
    principal
    {
        total-offset: uint,
        last-verification-date: uint,
        offset-method: (string-ascii 20),
        verification-status: bool,
        revocation-justification: (optional (string-ascii 50)),
        revocation-date: (optional uint),
        revoked-by: (optional principal)
    })

;; Private functions
(define-private (is-authorized-validator (validator principal))
    (default-to false (map-get? authorized-validators validator)))

(define-private (validate-description (input (string-ascii 20)))
    (let 
        ((length (len input)))
        (and (> length u0) (<= length u20))))

(define-private (validate-revocation-justification (justification (string-ascii 50)))
    (let 
        ((length (len justification)))
        (and (> length u0) (<= length u50))))

(define-private (can-revoke-verification (caller principal))
    (or 
        (is-eq caller contract-admin)
        (is-authorized-validator caller)))

;; Public functions

;; Add a new validator (only contract admin)
(define-public (add-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-admin) err-admin-only)
        ;; Check if validator is not the contract admin and not already authorized
        (asserts! (and 
            (not (is-eq validator contract-admin))
            (not (default-to false (map-get? authorized-validators validator)))
        ) err-invalid-validator)
        (map-set authorized-validators validator true)
        (ok true)))

;; Remove a validator (only contract admin)
(define-public (remove-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-admin) err-admin-only)
        ;; Check if validator exists and is not the contract admin
        (asserts! (and 
            (not (is-eq validator contract-admin))
            (default-to false (map-get? authorized-validators validator))
        ) err-invalid-validator)
        (map-delete authorized-validators validator)
        (ok true)))

;; Apply for verification
(define-public (apply-for-verification (offset-amount uint) (offset-method (string-ascii 20)))
    (let (
        (offsetter-data (default-to 
            {
                total-offset: u0,
                last-verification-date: u0,
                offset-method: "",
                verification-status: false,
                revocation-justification: none,
                revocation-date: none,
                revoked-by: none
            }
            (map-get? offsetter-carbon-data tx-sender)))
    )
        ;; Validate offset amount
        (asserts! (and 
            (>= offset-amount (var-get minimum-offset))
            (<= offset-amount (var-get max-offset))
        ) err-invalid-offset)
        ;; Validate offset method string
        (asserts! (validate-description offset-method) err-invalid-description)
        ;; Check if not already verified
        (asserts! (not (get verification-status offsetter-data)) err-already-verified)
        
        (map-set offsetter-carbon-data tx-sender
            {
                total-offset: offset-amount,
                last-verification-date: block-height,
                offset-method: offset-method,
                verification-status: false,
                revocation-justification: none,
                revocation-date: none,
                revoked-by: none
            })
        (ok true)))

;; Verify an offsetter (only authorized validators)
(define-public (verify-offsetter (offsetter principal))
    (let (
        (offsetter-data (default-to 
            {
                total-offset: u0,
                last-verification-date: u0,
                offset-method: "",
                verification-status: false,
                revocation-justification: none,
                revocation-date: none,
                revoked-by: none
            }
            (map-get? offsetter-carbon-data offsetter)))
    )
        ;; Validate validator authorization
        (asserts! (is-authorized-validator tx-sender) err-invalid-validator)
        ;; Check if not already verified
        (asserts! (not (get verification-status offsetter-data)) err-already-verified)
        ;; Check if offsetter has valid data
        (asserts! (> (get total-offset offsetter-data) u0) err-invalid-offset)
        
        ;; Update offsetter data with verification
        (map-set offsetter-carbon-data offsetter
            {
                total-offset: (get total-offset offsetter-data),
                last-verification-date: block-height,
                offset-method: (get offset-method offsetter-data),
                verification-status: true,
                revocation-justification: none,
                revocation-date: none,
                revoked-by: none
            })
        (map-set verified-offsetters offsetter true)
        (ok true)))

;; Enhanced revoke verification function (contract admin or authorized validators)
(define-public (revoke-verification (offsetter principal) (justification (string-ascii 50)))
    (begin
        ;; Check if caller is authorized to revoke
        (asserts! (can-revoke-verification tx-sender) err-not-permitted)
        ;; Check if offsetter is currently verified
        (asserts! (default-to false (map-get? verified-offsetters offsetter)) err-not-verified)
        ;; Validate revocation justification
        (asserts! (validate-revocation-justification justification) err-invalid-justification)
        
        ;; Get current offsetter data
        (let (
            (offsetter-data (unwrap! (map-get? offsetter-carbon-data offsetter) err-not-verified))
        )
            ;; Update offsetter data with revocation details
            (map-set offsetter-carbon-data offsetter
                {
                    total-offset: (get total-offset offsetter-data),
                    last-verification-date: (get last-verification-date offsetter-data),
                    offset-method: (get offset-method offsetter-data),
                    verification-status: false,
                    revocation-justification: (some justification),
                    revocation-date: (some block-height),
                    revoked-by: (some tx-sender)
                })
            (map-delete verified-offsetters offsetter)
            (ok true))))

;; Read-only functions

;; Check if an offsetter is verified
(define-read-only (is-verified (offsetter principal))
    (ok (default-to false (map-get? verified-offsetters offsetter))))

;; Get offsetter data including revocation history
(define-read-only (get-offsetter-data (offsetter principal))
    (ok (default-to
        {
            total-offset: u0,
            last-verification-date: u0,
            offset-method: "",
            verification-status: false,
            revocation-justification: none,
            revocation-date: none,
            revoked-by: none
        }
        (map-get? offsetter-carbon-data offsetter))))

;; Get verification cost
(define-read-only (get-verification-cost)
    (ok (var-get verification-cost)))

;; Set verification cost (only contract admin)
(define-public (set-verification-cost (new-cost uint))
    (begin
        (asserts! (is-eq tx-sender contract-admin) err-admin-only)
        ;; Validate new cost amount
        (asserts! (and 
            (> new-cost u0)
            (<= new-cost (var-get max-cost))
        ) err-invalid-cost)
        (var-set verification-cost new-cost)
        (ok true)))

;; Set minimum offset requirement (only contract admin)
(define-public (set-minimum-offset (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-admin) err-admin-only)
        ;; Validate new threshold amount
        (asserts! (and 
            (> new-threshold u0)
            (<= new-threshold (var-get max-offset))
        ) err-invalid-threshold)
        (var-set minimum-offset new-threshold)
        (ok true)))