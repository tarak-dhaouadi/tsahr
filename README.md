# tsahr

Trial Sequential Analysis (TSA) for meta-analyses of hazard ratios, in R.

Adapts the classical Wetterslev/Thorlund/Copenhagen Trial Unit TSA
framework to time-to-event outcomes, in the spirit of Miladinovic et al.
(2013). It's worth distinguishing what's established methodology versus
what this package specifically contributes:

**Established components** (from the cited literature):
- the Schoenfeld required-events sample-size formula for time-to-event
  outcomes, here generalised for **unequal allocation**,
- the **Diversity (D²)** heterogeneity adjustment of Wetterslev et al.
  (2009),
- the general trial-sequential-monitoring (alpha/beta-spending) framework.

**This package's specific implementation choices:**
- an HR-specific adaptation combining the above into one workflow,
- **inverse-variance information** based on each study's own reported
  log-HR standard error (`sum(1/SE^2)`), used as the accrued-information
  measure instead of a simpler event-count approximation,
- a compiled (C++) recursive numerical integration engine, ported from
  RTSA, for the O'Brien-Fleming-type alpha- and beta-spending boundaries
  (no external group-sequential-design package, and no fixed
  software-imposed limit on the number of looks, subject to available
  computational resources) -- see `?tsa_hr`, `src/rtsa_core.h` and
  `inst/REVERSE_ENGINEERING_RTSA.md`. The earlier R-only engine
  (`R/obf_boundaries.R`; validated against the published exact
  O'Brien-Fleming constant plus Monte Carlo type-I error control) is kept
  as a fallback that is ON by default (`legacy_fallback = TRUE`) and only
  runs if the compiled engine fails, clearly flagged in the result whenever
  it is used; set `legacy_fallback = FALSE` for confirmatory or RTSA-parity
  work,
- applying this monitoring framework to a **cumulative random-effects**
  meta-analysis Z-curve -- see the Caveats section below, this is an
  approximation shared with the official Copenhagen Trial Unit TSA
  software, not an exact result.

## Installation

```r
# install.packages("remotes")
remotes::install_github("tarak-dhaouadi/tsahr")
```

You'll also need its dependencies if you don't already have them:

```r
install.packages(c("metafor", "readxl", "ggplot2"))
```

## Usage

```r
library(tsahr)

# Try it on a bundled example dataset: 20 studies by default;
# tsahr_example_data("HR_meta_2") is the 40-study version
path <- tsahr_example_data()

res <- tsa_hr(
  data              = path,
  target_HR         = 0.80,   # pre-specified anticipated HR (recommended)
  alpha_two_sided   = 0.05,
  power             = 0.80,
  allocation_source = "data"  # or "manual" with allocation_p = ...
)

summary(res)   # full results table
plot(res)      # the TSA chart
```

The subtitle of the chart shows the model/design summary and, on a second
line, the pooled random-effects HR with its 95% CI, the p-value, tau² and I².
With `boundary_route = "analysis"`, the position and size of the
"Analysis-route endpoint ... reached" label can be set with
`endpoint_label_x`, `endpoint_label_y` and `endpoint_label_size`.

### Using your own data

`data` can be a data.frame or a path to an `.xlsx` file with one row per
study and (at least) these columns:

| Column             | Meaning                                   |
|--------------------|--------------------------------------------|
| `Study`            | Unique study label                        |
| `log_HR`           | log(hazard ratio) for that study          |
| `Std_Error`        | standard error of `log_HR`                |
| `Events_Treatment` | events in the treatment arm               |
| `N_treatment`      | patients randomised to treatment          |
| `Events_controls`  | events in the control arm                 |
| `N_controls`       | patients randomised to control            |

Rows should be in **chronological (publication) order** — TSA results
are order-dependent. Either pre-sort your data yourself, or pass
`order_by = "<column name>"` (e.g. a publication-year column) to have
`tsa_hr()` sort it for you explicitly:

```r
res <- tsa_hr(path, target_HR = 0.80, order_by = "Year")
```

### Saving the plot / results

`tsa_hr()` does not write files itself; use standard R tools:

```r
p <- plot(res)
ggplot2::ggsave("tsa_plot.png", p, width = 11, height = 7.5, dpi = 300)

write.csv(res$cumulative,    "tsa_cumulative_results.csv", row.names = FALSE)
write.csv(res$summary_table, "tsa_summary.csv",             row.names = FALSE)
```

## Important caveats

- **Circularity of `target_HR = NA`:** if you don't specify `target_HR`,
  the required information size is calculated from the *observed* pooled
  effect, which is circular and can make the TSA boundary collapse to
  the conventional boundary almost immediately. Set `target_HR` to a
  pre-specified, clinically-anticipated effect for a standard,
  publication-quality TSA. See `?tsa_hr` for details.
- **Random-effects approximation:** the plotted Z-curve is a cumulative
  random-effects meta-analysis, whose between-study variance is
  re-estimated at every step. The Lan-DeMets/O'Brien-Fleming monitoring
  boundaries strictly assume a fixed-information canonical process, so
  applying them to a random-effects Z-curve is a standard approximation
  (shared with the official Copenhagen Trial Unit TSA software), not an
  exact result.
- **`method` changes more than just the pooled effect estimate:** the
  heterogeneity-variance (`tau^2`) estimator selected via `method` does
  **not** change the mathematical alpha-spending function or the
  boundary-calculation algorithm -- those are a fixed part of the
  group-sequential design chosen up front (`alpha_two_sided`, `power`).
  However, because `method` changes `tau^2`, it also changes the pooled
  SE, the random-effects cumulative Z-curve, D-squared, DARIS, and the
  cumulative information schedule -- and therefore *which study
  corresponds to which information fraction*. So while the spending
  function itself is unaffected, switching, e.g., `method = "DL"` to
  `method = "REML"` can still change the boundary values attached to
  the observed looks indirectly, by changing the information schedule
  those looks land on, and therefore the practical timing of a boundary
  crossing.

## References

Miladinovic B, Mhaskar R, Hozo I, Kumar A, Mahony H, Djulbegovic B.
"Optimal information size in trial sequential analysis of time-to-event
outcomes reveals potentially inconclusive results because of the risk of
random error." *J Clin Epidemiol.* 2013;66(6):654-9.

Wetterslev J, Thorlund K, Brok J, Gluud C. "Estimating required
information size by quantifying diversity in random-effects model
meta-analyses." *BMC Med Res Methodol.* 2009;9:86.

## Attribution and license

tsahr contains code ported from the R package
[RTSA](https://cran.r-project.org/package=RTSA) (Anne Lyngholm Soerensen,
Markus Harboe Olsen, Theis Lange and Christian Gluud), licensed GPL (>= 2):
the C++ boundary engine (`src/rtsa_core.h`, `src/rtsa_engine.cpp`), its R
orchestration (`R/rtsa_engine.R`) and the earlier R-only reconstruction of it
(`R/obf_boundaries.R`). RTSA is the R version of Trial Sequential Analysis
(TSA), originally developed as a stand-alone Java program by the Copenhagen
Trial Unit; the RTSA manual is heavily inspired by the user manual for TSA by
Kristian Thorlund, Janus Engstrøm, Jørn Wetterslev, Jesper Brok, Georgina
Imberger and Christian Gluud. The original TSA software is available at
<https://ctu.dk/tools>:

> Copenhagen Trial Unit, Centre for Clinical Intervention Research,
> Department 3344, Rigshospitalet, DK-2100 Copenhagen Ø, Denmark.
> Tel. +45 3545 7171, Fax +45 3545 7101, E-mail: tsa@ctu.dk

Because of that, **tsahr is licensed GPL (>= 2)** (as of 0.2.7.22; earlier
releases were labelled MIT). See `inst/COPYRIGHTS` for the file-by-file
provenance. If you use tsahr for boundary computations please also cite RTSA
and the TSA software.
