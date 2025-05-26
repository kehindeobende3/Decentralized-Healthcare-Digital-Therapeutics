;; Patient Verification Contract
;; Manages participant identities and consent

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PATIENT_NOT_FOUND (err u201))
(define-constant ERR_PATIENT_ALREADY_EXISTS (err u202))
(define-constant ERR_CONSENT_REQUIRED (err u203))

;; Patient data structure
(define-map patients
  { patient-id: principal }
  {
    age-range: uint,
    gender: (string-ascii 10),
    medical-conditions: (string-ascii 200),
    consent-given: bool,
    consent-timestamp: uint,
    privacy-level: uint,
    active-status: bool
  }
)

;; Consent tracking
(define-map consent-history
  { patient-id: principal, consent-version: uint }
  {
    consent-text-hash: (buff 32),
    granted-at: uint,
    expires-at: uint
  }
)

;; Track patient counts
(define-data-var total-patients uint u0)
(define-data-var consent-version uint u1)

;; Register a new patient
(define-public (register-patient
  (patient-id principal)
  (age-range uint)
  (gender (string-ascii 10))
  (medical-conditions (string-ascii 200))
  (privacy-level uint))
  (begin
    (asserts! (is-none (map-get? patients { patient-id: patient-id })) ERR_PATIENT_ALREADY_EXISTS)

    (map-set patients
      { patient-id: patient-id }
      {
        age-range: age-range,
        gender: gender,
        medical-conditions: medical-conditions,
        consent-given: false,
        consent-timestamp: u0,
        privacy-level: privacy-level,
        active-status: true
      }
    )

    (var-set total-patients (+ (var-get total-patients) u1))
    (ok true)
  )
)

;; Grant consent
(define-public (grant-consent
  (patient-id principal)
  (consent-text-hash (buff 32))
  (expires-at uint))
  (let ((patient-data (unwrap! (map-get? patients { patient-id: patient-id }) ERR_PATIENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender patient-id) ERR_UNAUTHORIZED)

    ;; Update patient consent status
    (map-set patients
      { patient-id: patient-id }
      (merge patient-data {
        consent-given: true,
        consent-timestamp: block-height
      })
    )

    ;; Record consent history
    (map-set consent-history
      { patient-id: patient-id, consent-version: (var-get consent-version) }
      {
        consent-text-hash: consent-text-hash,
        granted-at: block-height,
        expires-at: expires-at
      }
    )

    (ok true)
  )
)

;; Revoke consent
(define-public (revoke-consent (patient-id principal))
  (let ((patient-data (unwrap! (map-get? patients { patient-id: patient-id }) ERR_PATIENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender patient-id) ERR_UNAUTHORIZED)

    (map-set patients
      { patient-id: patient-id }
      (merge patient-data { consent-given: false })
    )
    (ok true)
  )
)

;; Get patient information
(define-read-only (get-patient (patient-id principal))
  (map-get? patients { patient-id: patient-id })
)

;; Check if patient has valid consent
(define-read-only (has-valid-consent (patient-id principal))
  (match (map-get? patients { patient-id: patient-id })
    patient-data (get consent-given patient-data)
    false
  )
)

;; Get consent history
(define-read-only (get-consent-history (patient-id principal) (version uint))
  (map-get? consent-history { patient-id: patient-id, consent-version: version })
)

;; Get total patients
(define-read-only (get-total-patients)
  (var-get total-patients)
)
