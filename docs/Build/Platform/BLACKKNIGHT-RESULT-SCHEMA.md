\# BlackKnight Result Schema



\## Purpose



Every BlackKnight One engine should return structured output using a common schema.



This allows reports, dashboards, AI summaries, and future automation to consume results consistently.



\## Standard Fields



| Field | Purpose |

|---|---|

| Engine | Engine or capability name |

| Version | Engine version |

| Status | Planning, Framework, Integrated, Operational, Enterprise Ready |

| Health | Healthy, Warning, Critical |

| Confidence | Numeric confidence score from 0 to 100 |

| ChecksRun | Number of checks performed |

| Passed | Number of successful checks |

| Warnings | Number of warning findings |

| Failed | Number of failed findings |

| Timestamp | UTC time the engine ran |

| Evidence | Supporting observations |

| Recommendations | Suggested next actions |



\## Example



```json

{

&#x20; "Engine": "Workforce Lifecycle",

&#x20; "Version": "0.3.0-alpha",

&#x20; "Status": "Framework",

&#x20; "Health": "Healthy",

&#x20; "Confidence": 90,

&#x20; "ChecksRun": 5,

&#x20; "Passed": 5,

&#x20; "Warnings": 0,

&#x20; "Failed": 0,

&#x20; "Timestamp": "2026-07-08T00:00:00Z",

&#x20; "Evidence": \[

&#x20;   "Framework created",

&#x20;   "Supported workflows documented"

&#x20; ],

&#x20; "Recommendations": \[

&#x20;   "Add Microsoft Graph lifecycle validation"

&#x20; ]

}

