---
"gl-transitions": minor
---

Each transition has a `preview`: the `progress` of the frame that best represents it as a still image, for thumbnails and cards. Transitions set it with a `// Preview:` header line, 0.3 otherwise; the line doesn't change how they render. The Swift package and the Android library expose it too.
