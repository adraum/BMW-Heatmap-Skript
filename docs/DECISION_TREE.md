# Decision Tree

This document describes the current decision tree for identified watchouts.

---
## General 

### Models in Lifecycle

This decision tree is applicable for models in model-lifecycle.

It is not applicabple for Launch models  - within the phase between SOC and Market Launch.

It is not applicable for Runout models
- in the phase after the SOC of successor model,
- if there is no successor: in the phase after EOP

General Marketing Recommendation for Runoutmodels: if Stock Level is high, marketing / media push should be evaluated for Stock clearance.

### Priorization of models based on sales volume

To priorize model/market-combinations for marketing activities, evaluate the sales volume planned to ensure priorization of top-volume models (per market), based on Full Year Budget:
- C1: Order Intake
- C3/C4: Retail


---

## Watchout Detection

### IWVV Watchout
A case is treated as an IWVV watchout when `WEB`:
- contains `IWVV`, or
- contains a negative watchout marker such as `-1`, `-2`, or `-3`

Implementation note:
- Any `WEB` value containing a minus sign is treated as a negative-style watchout marker.

### NVWR Watchout
A case is treated as an NVWR watchout when `WEB`:
- contains `NVWR`, or
- contains a negative watchout marker such as `-1`, `-2`, or `-3`

### CRM Watchout
A case is treated as a CRM watchout when `CRM`:
- contains a negative watchout marker, or
- parses to a numeric value below `0`

Implementation note:
- Any `CRM` value containing a minus sign is treated as a negative-style watchout marker.

### Sales Watchout
A case is treated as a Sales watchout when:
- `SALES < 0`

### Watchout Duration
A watchout is treated as `>= 3 months` when any relevant watchout field contains `-3`.

---

## Node A

### A. Watchout in IWVV or NVWR?
- If `NO`: Proceed with `B`
- If `YES`: evaluate `A.1`

### A.1 Is it a watchout only in IWVV, and not in NVWR, CRM, or Sales?
- If `YES`: Proceed with `D`
- If `NO`: evaluate `A.1b`

### A.1b Is it a watchout only in NVWR, and not in IWVV, CRM, or Sales?
- If `YES`: Proceed with `B`
- If `NO`: evaluate `A.2`

### A.2 Does the watchout exist for at least 3 months?
- If `YES`: evaluate `A.3`
- If `NO`: evaluate `A.10`

### A.3 (Watchout in Sales and prediction does not indicate a chance) OR (prediction indicates a risk)?
Condition:
- (`Sales watchout exists` and `PRED != C`)
- OR `PRED = R`

- If `YES`: evaluate `A.4`
- If `NO`: Proceed with `B`

### A.4 Is Cost per NVWR efficient?
Thresholds:
- `BEV <= 200 EUR`
- `NON-BEV <= 100 EUR`
Mandatory additional condition:
- `Paid Share (IWVV Paid / IWVV) < 60%`
Evaluation behavior:
- Paid Share is evaluated even when Cost per NVWR is missing.
- If Cost per NVWR is missing, the cost condition is treated as met (efficient). `A.4` result then depends solely on whether `Paid Share < 60%`.

- If `YES`:
  - Recommendation: `Check potential increase of Media Activities  (good media mix)`
  - Proceed with `B`

- If `NO`:
  - Recommendation: `Evaluate and adjust Media Mix`
  - Proceed with `B`

### A.10 Is prediction a chance?
Condition:
- `PRED = C`

- If `YES`: Proceed with `B`
- If `NO`: Proceed with `A.4`

---

## Node B

### B. NVWR Watchout?
- If `NO`: Proceed with `C`
- If `YES`: evaluate `B.1`

### B.1 Is organic web conversion low?
Threshold:
- low if `< 0.9%`

CS handling:
- For market `CS`, the value is aggregated across `AT, BG, CZ, GR, HU, PL, RO, SI, SK`.
- If country-level aggregation is unavailable, a CS-specific fallback ratio is used.

Fallback for missing organic web conversion:
- If organic web conversion is not available, use overall web conversion.
- Formula: `NVWR / IWVV` (latest available values from MSF).

Root-cause wording:
- If the fallback is used, refer to it as `Overall Webconversion` (not `Organic Webconversion`).

- If `YES`:
  - Recommendation: `Check website journey`
  - Continue to `B.3`

- If `NO`:
  - Continue to `B.3`

If neither organic web conversion nor fallback overall web conversion is available:
- mark as `N/A`
- Proceed with `C`

### B.3 Is paid web conversion low?
Threshold:
- low if `< 0.7%`

CS handling:
- For market `CS`, the value is aggregated across `AT, BG, CZ, GR, HU, PL, RO, SI, SK`.
- If country-level aggregation is unavailable, a CS-specific fallback ratio is used.

- If `YES`:
  - Recommendation: `Check media campaigns`
  - Proceed with `C`

- If `NO`:
  - Proceed with `C`

If paid web conversion is not available:
- mark as `N/A`
- Proceed with `C`

---

## Node C

### C. Watchout in CRM?
- If `NO`: Proceed with `D`
- If `YES`: evaluate `C.1`

### C.1 Is prediction a chance?
Condition:
- `PRED = C`

- If `YES`: Proceed with `D`
- If `NO`: evaluate `C.2`

### C.2 CRM watchout duration and Sales/Prediction split
Condition flow:
- If CRM watchout duration is `< 3 months`: evaluate `C.3`
- If CRM watchout duration is `>= 3 months` and (`no Sales watchout` or `no PRED = R`): Proceed with `D`
- If CRM watchout duration is `>= 3 months` and (`Sales watchout` or `PRED = R`): evaluate `C.3`

### C.3 Are NSC Prospects on track?
Condition:
- actual `>=` benchmark

- If `YES`: evaluate `C.4`
- If `NO`:
  - Recommendation: `Check potential for lead generation.`
  - Proceed with `D`

If NSC Prospects are not available:
- mark as `N/A`
- Proceed with `D`

### C.4 Is Share of High Value NVWR OK?
Threshold:
- OK if `>= 40%`

- If `YES`: Proceed with `D`
- If `NO`:
  - Recommendation: `Check potential for prospect nurturing.`
  - Proceed with `D`

---

## Node D

### D. Watchout in Sales only OR (IWVV AND Sales only)?
- If `NO`: END
- If `YES`: evaluate `D.1`

### D.1 Is prediction a chance?
Condition:
- `PRED = C`

- If `YES`: END
- If `NO`:
  - Recommendation: `Check on Leadquality. If the Leadquality is good: evaluate potential COR measures.`
  - END

---

## Additional Chapter: Media Efficiency 

This chapter describes the logic used for the `Media Efficiency` view.

### Scope and ordering
- Evaluate all model/market/drivetrain combinations with high Media Cost.
- High-invest threshold: `Media Cost >= 70,000 EUR`.
- Results are sorted descending by `Media Cost`.

### CS aggregation rule
- For market `CS`, country-level entries are aggregated across `AT, BG, CZ, GR, HU, PL, RO, SI, SK`.
- The high-invest check for `CS` is applied on aggregated `Media Cost` (sum across these countries).
- For KPI checks in this chapter, existing CS regional aggregation/fallback logic applies.

### Step 1: Strong positive plan deviation check
Check whether all of the following are true:
- `IWVV plan deviation >= +20%`
- `NVWR plan deviation >= +10%`
- AND one of:
  - (`Sales plan deviation >= +5%` AND `Prediction != R`)
  - OR `Prediction = C`

Sales KPI selection:
- For `C1` markets: use `Order Intake - All`.
- For `C3/C4` markets: use `Retail - All`.

Sales plan deviation aggregation detail:
- Evaluate on `Model Range` level (ignore `Model Code`).
- For each relevant date, sum `Actual` and `Benchmark` across all model-code rows of the same model range.
- Use the latest available date aggregate for deviation.

If Step 1 is `YES`:
- Recommendation: `Evaluate shift in other models`
- Continue with Step 2.

If Step 1 is `NO`:
- Continue with Step 2.

### Step 2: Cost per NVWR efficiency
Thresholds:
- `BEV <= 200 EUR`
- `NON-BEV <= 100 EUR`

If Step 2 is `YES`:
- If there is no recommendation from Step 1, the model is not listed.
- If Step 1 already produced a recommendation, keep the model listed and continue no further checks.

If Step 2 is `NO`:
- Continue with Step 3.

### Step 3: Media Cost Conversion share
Check whether:
- `Media Cost Conversion / Media Cost > 40%`

If Step 3 is `NO`:
- Recommendation: `Evaluate and adjust Media Mix`
- Continue with Step 4.

If Step 3 is `YES`:
- Continue with Step 4.

### Step 4: Paid web conversion
Check whether:
- paid web conversion is low (`< 0.7%`).

If Step 4 is `YES`:
- Recommendation: `Check media campaigns`

If Step 4 is `NO`:
- End.

### Output behavior
- Only models with at least one recommendation are shown.
- Recommendation text can contain multiple entries joined in sequence when multiple conditions apply.

### Visual flow (compact)
```mermaid
flowchart TD
  A[Start: High Invest candidate<br/>Media Cost >= 70k] --> B{Step 1 strong positive?<br/>IWVV >= 20% and NVWR >= 10% and<br/>((Sales >= 5% and PRED != R) or PRED = C)}
  B -- Yes --> B1[Add Recommendation:<br/>Evaluate shift in other models]
  B -- No --> C
  B1 --> C{Step 2 Cost per NVWR efficient?<br/>BEV <= 200 / NON-BEV <= 100}
  C -- Yes --> D{Any recommendation already?}
  D -- No --> E[Do not list model]
  D -- Yes --> F[Keep model and end]
  C -- No --> G{Step 3 Media Cost Conversion Share > 40%?}
  G -- No --> G1[Add Recommendation:<br/>Evaluate and adjust Media Mix]
  G -- Yes --> H
  G1 --> H{Step 4 Paid Web Conversion low?<br/>< 0.7%}
  H -- Yes --> H1[Add Recommendation:<br/>Check media campaigns]
  H -- No --> I[End]
  H1 --> I
```

---

## Supporting KPI Notes

### Organic web conversion
- low if `< 0.9%`

### Paid web conversion
- low if `< 0.7%`

### High Value NVWR Share
- OK if `>= 40%`

### Cost per NVWR
- BEV efficient if `<= 200 EUR` and `Paid Share < 60%`
- NON-BEV efficient if `<= 100 EUR` and `Paid Share < 60%`
- If Cost per NVWR is missing, the cost condition is treated as met. Efficiency is then determined solely by `Paid Share < 60%`.
- For market `CS`, Cost per NVWR and Paid Share are evaluated as regional aggregates across `AT, BG, CZ, GR, HU, PL, RO, SI, SK`.
