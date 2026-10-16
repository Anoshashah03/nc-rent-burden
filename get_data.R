# ==============================================================
#  NC Rent Burden Analysis
# --------------------------------------------------------------
#  Author:   Anosha Shah
#  Purpose:  Find where North Carolina renters spend the largest
#            share of their income on rent, and how that has
#            changed from 2015 to 2022.
#  Source:   U.S. Census Bureau, American Community Survey (ACS)
#  Output:   rent.rds (read by app.R)
# ==============================================================


# ---- 1. Packages ---------------------------------------------
library(tidycensus)   # Census API access
library(tidyverse)    # data wrangling


# ---- 2. Settings ---------------------------------------------
# 5-year estimates, because 1-year data doesn't cover small counties
years <- 2015:2022

# NC has used the federal minimum wage the whole period
min_wage <- 7.25

# Census variable codes, renamed so the code below is readable
acs_vars <- c(
  median_rent_pct = "B25071_001",  # median rent as % of household income
  median_rent_usd = "B25064_001",  # median gross rent in dollars
  median_income   = "B19013_001",  # median household income
  renters_total   = "B25070_001",  # all renter households
  b30_35          = "B25070_007",  # paying 30-34.9% of income on rent
  b35_40          = "B25070_008",  # 35-39.9%
  b40_50          = "B25070_009",  # 40-49.9%
  b50_plus        = "B25070_010",  # 50% or more
  not_computed    = "B25070_011"   # ratio could not be computed
)


# ---- 3. Pull the data ----------------------------------------
# One request per year, stacked into a single table.
# output = "wide" gives an estimate (E) and a margin of error (M)
# column for every variable.
pull_year <- function(y) {
  get_acs(
    geography = "county",
    state     = "NC",
    variables = acs_vars,
    year      = y,
    survey    = "acs5",
    output    = "wide"
  ) %>%
    mutate(year = y)
}

rent_raw <- map_dfr(years, pull_year)


# ---- 4. Build the measures -----------------------------------
# Cost-burdened = paying 30%+ of income on rent.
# Households where the ratio couldn't be computed are left out of
# the denominator so they don't pull the percentages down.
rent <- rent_raw %>%
  mutate(
    classified     = renters_totalE - not_computedE,
    classified_moe = sqrt(renters_totalM^2 + not_computedM^2),
    burdened_n     = b30_35E + b35_40E + b40_50E + b50_plusE,
    burdened_n_moe = sqrt(b30_35M^2 + b35_40M^2 + b40_50M^2 + b50_plusM^2)
  ) %>%
  transmute(
    GEOID,
    county = str_remove(NAME, " County, North Carolina"),
    year,
    median_rent_pct = median_rent_pctE,
    median_rent_usd = median_rent_usdE,
    median_income   = median_incomeE,
    renters         = renters_totalE,
    
    # share of renters paying 30%+ of income, with margin of error
    burdened_pct     = burdened_n / classified * 100,
    burdened_pct_moe = moe_prop(burdened_n, classified,
                                burdened_n_moe, classified_moe) * 100,
    
    # share of renters paying 50%+ of income
    severe_pct = b50_plusE / classified * 100,
    
    # full-time (40 hr/week) minimum-wage jobs needed to afford the
    # median rent while spending no more than 30% of income on it
    min_wage_jobs = (median_rent_usdE / 0.30) * 12 / 52 / min_wage / 40,
    
    # reliability flag: the margin of error is a 90% interval, so
    # divide by 1.645 for the standard error, then compare to the
    # estimate. A CV above 30% is a common "unreliable" cutoff.
    cv = (median_rent_pctM / 1.645) / median_rent_pctE * 100,
    low_reliability = cv > 30
  ) %>%
  mutate(across(c(burdened_pct, burdened_pct_moe, severe_pct,
                  min_wage_jobs, cv), ~ round(.x, 1)))


# ---- 5. Checks -----------------------------------------------
# 100 counties x 8 years = 800 rows. Stop if anything is missing.
stopifnot(nrow(rent) == 100 * length(years))

# Count missing values by column (a few in small counties is okay)
colSums(is.na(rent))


# ---- 6. Save for the app -------------------------------------
# The app reads this file, so it never needs the API or my key.
saveRDS(rent, "rent.rds")