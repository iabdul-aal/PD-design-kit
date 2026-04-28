# AI Enhancement Plan

This repository currently contains one active thesis chapter source:

- `thesis/chapter_photodetector.tex`

The next AI should treat this file as the source of truth for the written chapter, and the simulation/layout/project repository content as the source of truth for anything numerical, structural, or implementation-specific that can be verified from the project itself.

## Working Rules

Use these rules in every pass:

1. Do not rewrite for the sake of tone alone. Extend, tighten, or correct only where the physical argument, mathematical derivation, or engineering logic improves.
2. Every major claim must be supported by one of: derivation, simulation evidence, literature comparison, or system-level implication.
3. Every important design trade-off must be quantified and plotted, not only described qualitatively.
4. Discussion paragraphs should follow an evidence-to-interpretation pattern: state the result, explain the mechanism, compare with expectation or literature, then state the design implication.
5. Citations must stay standardized and consistent across the chapter.

Useful style references for the next AI:

- Oxford discussion guidance: https://www.conted.ox.ac.uk/about/writing-discussion-sections
- Oxford literature review guidance: https://www.conted.ox.ac.uk/about/writing-literature-reviews
- MIT research checklist: https://web.mit.edu/21w732/www/Handouts/research-checklist.htm
- CMU engineering thesis standards: https://engineering.cmu.edu/education/academic-policies/graduate-policies/thesis-dissertation.html

## Mandatory Sync Loop

Before editing the thesis, the next AI should:

1. Read the latest project-side simulation results, scripts, layout files, and generated figures.
2. Extract any project changes that affect dimensions, material constants, operating wavelength, bias conditions, circuit values, or system assumptions.
3. Update the chapter only after verifying those values from the project.

Before editing the project, the next AI should:

1. Read the latest thesis chapter.
2. Extract every unresolved claim, promised sweep, placeholder figure, and system-level requirement.
3. Update the project so it generates the missing evidence required by the thesis.

The thesis and project should therefore be enhanced in alternating passes:

1. Project-to-thesis sync
2. Thesis refinement
3. Thesis-to-project gap extraction
4. Project refinement
5. Repeat until no unresolved placeholders remain except intentionally deferred future work

## Section-by-Section Enhancement Prompts

The file is one chapter, but it should be enhanced section by section. Use one prompt at a time.

### 1. Physical Foundations and Metric Formalisation

Goal:
Strengthen first-principles derivations, remove any unsupported shortcut, and ensure that every metric is traced back to underlying field, transport, or noise physics.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Physical Foundations and Metric Formalisation". Do not rewrite later sections. Check every equation for physical consistency, unit consistency, and notation consistency. Expand derivations only where the current text jumps too quickly from assumption to final formula. In particular, verify the derivation path for absorption, generation rate, drift-diffusion transport, transfer function, RC response, shot noise, thermal noise, and NEP/D*. Add figure placeholders only where a physical mechanism still lacks a visual explanation. Use the current project values as the numerical source of truth whenever available.
```

### 2. Literature Review and State-of-the-Art Positioning

Goal:
Tighten the literature logic so the review does not become a list of papers, but a causal map of how the field moved from one limitation to the next.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Literature Review and State-of-the-Art Positioning". Preserve the current references and structure unless a correction is necessary. Reframe each paper as an intervention on a specific bottleneck: absorption, RC parasitics, transit time, dark current, saturation power, or integration complexity. Make the straight-versus-U-shape comparison sharper and explicitly connect each literature step to the equations already defined earlier in the chapter. If project data now supports a better benchmark comparison table, update the table carefully and keep all claims source-backed.
```

### 3. Device Architecture and Simulation Methodology

Goal:
Make the chapter read like a reproducible engineering workflow rather than a descriptive methods note.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Device Architecture and Simulation Methodology". Use the latest project files as the authoritative reference for geometry, materials, doping, taper design, boundary conditions, solver settings, mesh strategy, convergence criteria, and extracted outputs. Remove vague wording. If any parameter is not directly justified, add the physical or numerical reason for its value. Ensure the text makes clear what was simulated in FDTD, what was simulated in CHARGE, what was inferred analytically, and what was only cross-validated by PINN.
```

### 4. Device Evolution: From Photoconductor to Waveguide-Integrated PIN

Goal:
Keep this section as the intuition engine of the chapter: progressive, rigorous, and visually grounded.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Device Evolution: From Photoconductor to Waveguide-Integrated PIN". Do not summarize. Preserve the progressive flow photoconductor -> PN -> PIN -> Ge choice -> waveguide coupling. Strengthen the why-questions: why PIN not APD, why Ge not Si, why vertical PIN, why waveguide plus taper, why not surface-normal illumination. Every major transition must be supported by at least one equation or inequality and one figure placeholder if the mechanism is still hard to visualize. Make the section feel physically inevitable, not just historically descriptive.
```

### 5. Electrode Topology: From Straight to U-shaped Anode

Goal:
Turn the topology choice into a clean electro-optical co-design argument.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Electrode Topology: From Straight to U-shaped Anode". Focus on the coupling between lateral current path, series resistance, capacitance loading, inductive peaking, and the effective detector transfer function. Tighten the distinction between the conservative lower-bound bandwidth model and the benchmark-calibrated peaked response. Make sure the final text proves why the U-shape is selected, not just that it performs better in one example.
```

### 6. Results

Goal:
Make the results section quantitatively complete, especially for O-band adaptation and trade-off sweeps.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Results". Use the latest project simulations to verify every reported number. Prioritize the absorber-length sweep, intrinsic-thickness sweep, electrostatic profiles, responsivity extraction, and bandwidth projection. Add or refine figure placeholders for any missing trade-off plot. Make the O-band adaptation logic explicit: what changed from the benchmark design, what stayed fixed, and what numerical consequences followed. If the project now contains newer sweeps, update the text and tables from those results only.
```

### 7. Discussion

Goal:
Make this section interpretive and design-oriented, not repetitive.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Discussion". Structure each paragraph as result -> mechanism -> implication. Avoid repeating raw numbers unless they are used analytically. Focus on the absorber-length knee, dark-current sensitivity, screening threshold, compactness versus capacitance, bondpad parasitics, transport limits, and the practical implications of the vertical architecture. If any discussion claim is stronger than the evidence supports, reduce it to the level actually justified by the chapter.
```

### 8. Device-to-System Projection and IEEE 802.3 400GBASE-DR4

Goal:
Make the system section read like a credible receiver-design bridge, not a disconnected appendix.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Device-to-System Projection and IEEE 802.3 400GBASE-DR4". Use the current device metrics and the latest project/system assumptions as the basis. Verify the link between detector responsivity, dark current, bandwidth, screening threshold, receiver sensitivity, modulation format, and TIA requirements. Keep the section independent of PINN. Make sure every compliance statement is traceable to either a table, an equation, or a literature/reference-backed standard value.
```

### 9. Physics-Informed Neural Network: Validation and Double U-shape Extension

Goal:
Keep the novel contribution strong without over-claiming accuracy.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Physics-Informed Neural Network: Validation and Double U-shape Extension". First validate that every PINN claim is clearly separated from CHARGE/FDTD evidence. Tighten the validation criteria, the training description, and the interpretation of the double-U exploration. Do not present the PINN as a replacement for full simulation; present it as a validated surrogate for trend exploration after calibration. If the project now contains improved PINN training logs, new error metrics, or double-U comparisons, integrate them carefully.
```

### 10. Conclusion and Outlook

Goal:
End the chapter with a strong research position, not a generic summary.

Prompt for next AI:

```text
Open thesis/chapter_photodetector.tex and improve only the section "Conclusion". Keep the conclusion evidence-based and aligned with the actual chapter results. Remove any inflated phrasing. Emphasize what was established physically, what was validated numerically, what was demonstrated at system level, and where the architecture sits relative to current high-speed optical interconnect trends. Avoid a weak "future work" list; instead discuss concrete research directions and industry relevance.
```

## Project-to-Thesis Prompt

Use this when the next AI should update the project first.

```text
Read thesis/chapter_photodetector.tex and extract every unresolved figure placeholder, parameter sweep, missing validation comparison, and system-level claim that should be backed by project evidence. Then inspect the latest simulation/layout/system files in the repository and implement the missing project-side work needed to support the chapter. Generate outputs in a thesis-ready form: reusable figures, tables, extracted metrics, and short notes on assumptions and solver settings.
```

## Thesis-to-Project Prompt

Use this when the next AI should update the chapter first.

```text
Read the latest project outputs and identify every thesis paragraph in thesis/chapter_photodetector.tex that is outdated, under-evidenced, or inconsistent with the project. Update the chapter only where the project provides direct support. Preserve the current chapter structure and technical level. Strengthen the physical interpretation, mathematical grounding, and engineering justification without reducing detail.
```

## End Condition

The chapter is ready for a final polishing pass only when:

1. No placeholder figure remains without a corresponding planned asset.
2. Every table value can be traced to either project output, literature, or explicit analytical derivation.
3. No section mixes baseline-model numbers with benchmark-calibrated numbers without stating the difference.
4. The thesis chapter and project outputs agree on geometry, wavelength, bias, and system assumptions.
5. The standalone chapter check builds cleanly enough for iterative writing, and the full thesis build uses the same source values.
