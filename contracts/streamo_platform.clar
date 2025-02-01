;; Streamo Platform Contract

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-already-registered (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-reward-tier (err u104))

;; Define token
(define-fungible-token strm-token)

;; Data vars
(define-map creators 
    principal 
    {
        name: (string-ascii 50),
        total-views: uint,
        total-earnings: uint,
        engagement-score: uint,
        reward-tier: uint
    }
)

(define-map videos 
    uint 
    {
        creator: principal,
        title: (string-ascii 100), 
        description: (string-ascii 500),
        views: uint,
        tips: uint,
        likes: uint,
        comments: uint
    }
)

(define-map reward-tiers
    uint
    {
        name: (string-ascii 20),
        multiplier: uint,
        threshold: uint
    }
)

(define-data-var video-counter uint u0)

;; Initialize reward tiers
(begin
    (map-set reward-tiers u1 {name: "Bronze", multiplier: u1, threshold: u0})
    (map-set reward-tiers u2 {name: "Silver", multiplier: u2, threshold: u1000})
    (map-set reward-tiers u3 {name: "Gold", multiplier: u3, threshold: u5000})
    (map-set reward-tiers u4 {name: "Diamond", multiplier: u5, threshold: u10000})
)

;; Creator registration
(define-public (register-creator (name (string-ascii 50)))
    (let ((creator-data (map-get? creators tx-sender)))
        (if (is-some creator-data)
            err-already-registered
            (begin
                (map-set creators tx-sender {
                    name: name,
                    total-views: u0,
                    total-earnings: u0,
                    engagement-score: u0,
                    reward-tier: u1
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
                    tips: u0,
                    likes: u0,
                    comments: u0
                })
                (var-set video-counter (+ video-id u1))
                (ok video-id)
            )
        )
    )
)

;; Calculate rewards based on tier
(define-private (calculate-rewards (creator-data {name: (string-ascii 50), total-views: uint, total-earnings: uint, engagement-score: uint, reward-tier: uint}))
    (let ((tier-data (unwrap! (map-get? reward-tiers (get reward-tier creator-data)) (err u404))))
        (* u1 (get multiplier tier-data))
    )
)

;; Update reward tier
(define-private (update-reward-tier (creator principal) (engagement-score uint))
    (let ((creator-data (unwrap! (map-get? creators creator) (err u404))))
        (if (>= engagement-score u10000)
            (map-set creators creator (merge creator-data {reward-tier: u4}))
            (if (>= engagement-score u5000)
                (map-set creators creator (merge creator-data {reward-tier: u3}))
                (if (>= engagement-score u1000)
                    (map-set creators creator (merge creator-data {reward-tier: u2}))
                    (map-set creators creator (merge creator-data {reward-tier: u1}))
                )
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
            (let ((new-engagement (+ (get engagement-score creator-data) u1)))
                (map-set creators (get creator video-data) (merge creator-data {
                    total-views: (+ (get total-views creator-data) u1),
                    engagement-score: new-engagement
                }))
                ;; Update reward tier
                (update-reward-tier (get creator video-data) new-engagement)
            )
            
            ;; Mint rewards based on tier
            (try! (ft-mint? strm-token (calculate-rewards creator-data) (get creator video-data)))
            (ok true)
        )
    )
)

;; Like video
(define-public (like-video (video-id uint))
    (let ((video-data (unwrap! (map-get? videos video-id) (err u404))))
        (begin
            (map-set videos video-id (merge video-data {likes: (+ (get likes video-data) u1)}))
            (ok true)
        )
    )
)

;; Comment on video
(define-public (comment-video (video-id uint))
    (let ((video-data (unwrap! (map-get? videos video-id) (err u404))))
        (begin
            (map-set videos video-id (merge video-data {comments: (+ (get comments video-data) u1)}))
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

(define-read-only (get-reward-tier (tier-id uint))
    (ok (map-get? reward-tiers tier-id))
)
