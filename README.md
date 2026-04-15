# sap-rfc-se16n

SE16N-like ABAP report to query the same table across multiple RFC destinations and compare results in one ALV.

## What it does

Reads the same table from N RFC destinations and shows the merged result in a single ALV. The first column identifies the source RFC so rows from different systems can be compared side-by-side.

The selection screen is styled to mimic transaction **SE16N**.

## Selection screen mapping

| SE16N element | In this report |
|---|---|
| Table | `P_TABLE` |
| Maximum no. of hits | `P_MAX` (default 500) — caps rows across all RFCs |
| "Selection Criteria" frame | `BLOCK b3 WITH FRAME TITLE` — holds `P_SELECT` (field list) and `P_WHERE` |
| RFC multi-input *(new)* | `BLOCK b2` with `SELECT-OPTIONS s_rfc ... NO INTERVALS` |

## Notes

- The structure is resolved once from the first RFC in the list; all RFCs are expected to return the same layout for the chosen table.
- Per-RFC failures are reported as info messages; the report continues with the remaining RFCs.
- `P_MAX` is a hard cap across all RFCs combined.
- The full per-field SE16N grid (Technical name / Fr.Value / To value / More / Output…) is **not** reproduced — that requires a custom dynpro with a table control. The plain `SELECT` / `WHERE` inputs cover the same capability in text form.
