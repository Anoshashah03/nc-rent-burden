# ==============================================================
#  NC Rent Burden Analysis
# --------------------------------------------------------------
#  Author:   Anosha Shah
#  Purpose:  Download NC county boundaries once and save them,
#            so the app can draw maps without re-downloading.
#  Source:   U.S. Census Bureau TIGER/Line shapefiles
#  Script:   Map data prep (saves nc_counties.rds for the app)
# ==============================================================

# ---- 1. Packages ---------------------------------------------
library(tigris)      # county boundary files
library(sf)          # spatial data
library(tidyverse)

options(tigris_use_cache = TRUE)   # don't re-download every run


# ---- 2. Pull county shapes -----------------------------------
# cb = TRUE gives simplified boundaries, which load much faster
# in the app and look fine at state level.
nc_counties <- counties(state = "NC", cb = TRUE, year = 2022) %>%
  select(GEOID, geometry) %>%
  st_transform(4326)   # lat/long, which leaflet expects


# ---- 3. Checks -----------------------------------------------
# Every county needs to match a row in rent.rds, or the map will
# have holes.
rent <- readRDS("rent.rds")
stopifnot(nrow(nc_counties) == 100)
stopifnot(all(nc_counties$GEOID %in% rent$GEOID))


# ---- 4. Save for the app -------------------------------------
saveRDS(nc_counties, "nc_counties.rds")

# Quick look to confirm the shapes are right
plot(st_geometry(nc_counties))