;; Cultural Continuity Contract
;; Ensures consciousness legacy cultural continuity and preservation

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_CULTURE_NOT_FOUND (err u501))
(define-constant ERR_TRADITION_NOT_FOUND (err u502))
(define-constant ERR_INVALID_PRIORITY (err u503))

;; Cultural priority levels
(define-constant PRIORITY_LOW u1)
(define-constant PRIORITY_MEDIUM u2)
(define-constant PRIORITY_HIGH u3)
(define-constant PRIORITY_CRITICAL u4)

;; Data structures
(define-map cultural-contexts
  { culture-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    origin-region: (string-ascii 100),
    language: (string-ascii 50),
    preservation-priority: uint,
    active-practitioners: uint,
    legacy-count: uint
  }
)

(define-map cultural-traditions
  { tradition-id: uint }
  {
    culture-id: uint,
    name: (string-ascii 100),
    description: (string-ascii 400),
    practice-type: (string-ascii 50),
    transmission-method: (string-ascii 100),
    risk-level: uint,
    documented-legacies: (list 20 uint)
  }
)

(define-map legacy-cultural-mapping
  { legacy-id: uint }
  {
    culture-id: uint,
    tradition-ids: (list 10 uint),
    cultural-significance: uint,
    preservation-urgency: uint
  }
)

(define-map cultural-preservation-goals
  { culture-id: uint }
  {
    target-legacy-count: uint,
    current-legacy-count: uint,
    preservation-deadline: uint,
    funding-needed: uint,
    community-support: uint
  }
)

(define-data-var next-culture-id uint u1)
(define-data-var next-tradition-id uint u1)

;; Register cultural context
(define-public (register-cultural-context (name (string-ascii 100))
                                         (description (string-ascii 300))
                                         (origin-region (string-ascii 100))
                                         (language (string-ascii 50))
                                         (preservation-priority uint))
  (let ((culture-id (var-get next-culture-id)))
    (asserts! (and (>= preservation-priority u1) (<= preservation-priority u4)) ERR_INVALID_PRIORITY)

    (map-set cultural-contexts
      { culture-id: culture-id }
      {
        name: name,
        description: description,
        origin-region: origin-region,
        language: language,
        preservation-priority: preservation-priority,
        active-practitioners: u0,
        legacy-count: u0
      }
    )

    (map-set cultural-preservation-goals
      { culture-id: culture-id }
      {
        target-legacy-count: u10,
        current-legacy-count: u0,
        preservation-deadline: (+ block-height u52560), ;; ~1 year
        funding-needed: u0,
        community-support: u0
      }
    )

    (var-set next-culture-id (+ culture-id u1))
    (ok culture-id)
  )
)

;; Register cultural tradition
(define-public (register-cultural-tradition (culture-id uint)
                                           (name (string-ascii 100))
                                           (description (string-ascii 400))
                                           (practice-type (string-ascii 50))
                                           (transmission-method (string-ascii 100))
                                           (risk-level uint))
  (let ((tradition-id (var-get next-tradition-id)))
    (asserts! (is-some (map-get? cultural-contexts { culture-id: culture-id })) ERR_CULTURE_NOT_FOUND)
    (asserts! (and (>= risk-level u1) (<= risk-level u5)) ERR_INVALID_PRIORITY)

    (map-set cultural-traditions
      { tradition-id: tradition-id }
      {
        culture-id: culture-id,
        name: name,
        description: description,
        practice-type: practice-type,
        transmission-method: transmission-method,
        risk-level: risk-level,
        documented-legacies: (list)
      }
    )

    (var-set next-tradition-id (+ tradition-id u1))
    (ok tradition-id)
  )
)

;; Map legacy to cultural context
(define-public (map-legacy-to-culture (legacy-id uint)
                                     (culture-id uint)
                                     (tradition-ids (list 10 uint))
                                     (cultural-significance uint)
                                     (preservation-urgency uint))
  (begin
    (asserts! (is-some (map-get? cultural-contexts { culture-id: culture-id })) ERR_CULTURE_NOT_FOUND)
    (asserts! (and (>= cultural-significance u1) (<= cultural-significance u5)) ERR_INVALID_PRIORITY)
    (asserts! (and (>= preservation-urgency u1) (<= preservation-urgency u5)) ERR_INVALID_PRIORITY)

    (map-set legacy-cultural-mapping
      { legacy-id: legacy-id }
      {
        culture-id: culture-id,
        tradition-ids: tradition-ids,
        cultural-significance: cultural-significance,
        preservation-urgency: preservation-urgency
      }
    )

    ;; Update culture legacy count
    (match (map-get? cultural-contexts { culture-id: culture-id })
      culture-data
      (map-set cultural-contexts
        { culture-id: culture-id }
        (merge culture-data { legacy-count: (+ (get legacy-count culture-data) u1) })
      )
      false
    )

    ;; Update preservation goals
    (match (map-get? cultural-preservation-goals { culture-id: culture-id })
      goals-data
      (map-set cultural-preservation-goals
        { culture-id: culture-id }
        (merge goals-data { current-legacy-count: (+ (get current-legacy-count goals-data) u1) })
      )
      false
    )

    (ok true)
  )
)

;; Update preservation goals
(define-public (update-preservation-goals (culture-id uint)
                                        (target-legacy-count uint)
                                        (preservation-deadline uint)
                                        (funding-needed uint))
  (match (map-get? cultural-preservation-goals { culture-id: culture-id })
    goals-data
    (begin
      (map-set cultural-preservation-goals
        { culture-id: culture-id }
        (merge goals-data {
          target-legacy-count: target-legacy-count,
          preservation-deadline: preservation-deadline,
          funding-needed: funding-needed
        })
      )
      (ok true)
    )
    ERR_CULTURE_NOT_FOUND
  )
)

;; Get cultural context
(define-read-only (get-cultural-context (culture-id uint))
  (map-get? cultural-contexts { culture-id: culture-id })
)

;; Get cultural tradition
(define-read-only (get-cultural-tradition (tradition-id uint))
  (map-get? cultural-traditions { tradition-id: tradition-id })
)

;; Get legacy cultural mapping
(define-read-only (get-legacy-cultural-mapping (legacy-id uint))
  (map-get? legacy-cultural-mapping { legacy-id: legacy-id })
)

;; Get preservation goals
(define-read-only (get-preservation-goals (culture-id uint))
  (map-get? cultural-preservation-goals { culture-id: culture-id })
)

;; Get cultures by priority
(define-read-only (get-culture-count)
  (var-get next-culture-id)
)

;; Get tradition count
(define-read-only (get-tradition-count)
  (var-get next-tradition-id)
)
