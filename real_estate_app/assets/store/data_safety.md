# Patamjengo — Play Store Data Safety Declaration

Complete this in Play Console → App content → Data safety.

---

## Does your app collect or share any of the required user data types?

**Answer: YES**

---

## Data Collected and Shared

### 1. Location
| Field | Value |
|-------|-------|
| Collected? | Yes |
| Shared? | No (processed on device / Supabase only) |
| Required or optional? | Optional (user grants on first search) |
| Purpose | App functionality — property search near user |
| Is it processed ephemerally? | No (used during session) |

### 2. Personal info — Name
| Field | Value |
|-------|-------|
| Collected? | Yes |
| Shared? | No |
| Required or optional? | Required (for account) |
| Purpose | Account management |

### 3. Personal info — Email address
| Field | Value |
|-------|-------|
| Collected? | Yes |
| Shared? | No |
| Required or optional? | Required |
| Purpose | Account management, notifications |

### 4. Personal info — User IDs
| Field | Value |
|-------|-------|
| Collected? | Yes (Supabase UUID) |
| Shared? | No |
| Required or optional? | Required |
| Purpose | Account management |

### 5. Photos and videos
| Field | Value |
|-------|-------|
| Collected? | Yes (user uploads property photos/videos) |
| Shared? | Yes (displayed to other users on listings) |
| Required or optional? | Optional |
| Purpose | App functionality (property listings) |

### 6. Financial info — Purchase history
| Field | Value |
|-------|-------|
| Collected? | Yes (if Selcom payments enabled) |
| Shared? | No (processed server-side) |
| Required or optional? | Optional |
| Purpose | Payments (subscription / listing fees) |

### 7. Messages
| Field | Value |
|-------|-------|
| Collected? | Yes (in-app chat messages) |
| Shared? | No (between users within app only) |
| Required or optional? | Optional |
| Purpose | App functionality (messaging) |

### 8. App activity — App interactions
| Field | Value |
|-------|-------|
| Collected? | Yes (property views, search queries) |
| Shared? | No |
| Required or optional? | Required |
| Purpose | Analytics, app functionality |

---

## Security Practices

| Question | Answer |
|----------|--------|
| Is data encrypted in transit? | **Yes** — all traffic uses HTTPS/TLS |
| Do you provide a way for users to request data deletion? | **Yes** — via account settings or email to support |

---

## Notes

- The app uses **Supabase** as its backend. No data is sent to Firebase (google-services.json is only for Google Sign-In OAuth).
- Location data is **foreground-only** — no background location tracking.
- Payment processing is handled **server-side** (Node.js backend + Selcom) — card numbers never touch the Flutter app.
- All user-uploaded content (photos, videos) is stored in **Supabase Storage**.
