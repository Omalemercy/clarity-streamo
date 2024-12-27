;; Streamo Platform Contract

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-insufficient-balance (err u103))

;; Define token
(define-fungible-token strm-token)

;; Data vars
(define-map creators 
    principal 
    {
        name: (string-ascii 50),
        total-views: uint,
        total-earnings: uint
    }
)

(define-map videos 
    uint 
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        views: uint,
        tips: uint
    }
)

(define-data-var video-counter uint u0)

;; Creator registration
(define-public (register-creator (name (string-ascii 50)))
    (let ((creator-data (map-get? creators tx-sender)))
        (if (is-some creator-data)
            err-already-registered
            (begin
                (map-set creators tx-sender {
                    name: name,
                    total-views: u0,
                    total-earnings: u0
                })
                (ok true)
            )
        )
    )
)

;; Video publishing
(define-public (publish-video (title (string-ascii 100)) (description (string-ascii 500)))
    (let ((creator-data (map-get? creators tx-sender)))
        (if (is-none creator-data)
            err-not-registered
            (let ((video-id (var-get video-counter)))
                (map-set videos video-id {
                    creator: tx-sender,
                    title: title,
                    description: description,
                    views: u0,
                    tips: u0
                })
                (var-set video-counter (+ video-id u1))
                (ok video-id)
            )
        )
    )
)

;; Record view and distribute rewards
(define-public (record-view (video-id uint))
    (let (
        (video-data (unwrap! (map-get? videos video-id) (err u404)))
        (creator-data (unwrap! (map-get? creators (get creator video-data)) (err u404)))
    )
        (begin
            ;; Update video views
            (map-set videos video-id (merge video-data {views: (+ (get views video-data) u1)}))
            ;; Update creator stats
            (map-set creators (get creator video-data) (merge creator-data {
                total-views: (+ (get total-views creator-data) u1)
            }))
            ;; Mint rewards
            (try! (ft-mint? strm-token u1 (get creator video-data)))
            (ok true)
        )
    )
)

;; Tip creator
(define-public (tip-creator (video-id uint) (amount uint))
    (let (
        (video-data (unwrap! (map-get? videos video-id) (err u404)))
    )
        (begin
            ;; Transfer tokens
            (try! (ft-transfer? strm-token amount tx-sender (get creator video-data)))
            ;; Update video tips
            (map-set videos video-id (merge video-data {
                tips: (+ (get tips video-data) amount)
            }))
            (ok true)
        )
    )
)

;; Read-only functions
(define-read-only (get-creator-data (creator principal))
    (ok (map-get? creators creator))
)

(define-read-only (get-video-data (video-id uint))
    (ok (map-get? videos video-id))
)

(define-read-only (get-total-videos)
    (ok (var-get video-counter))
)