library(sf)
library(dplyr)
library(tidyr)
library(mapme.biodiversity)

# read data
src <- "output/adm2_polygons_conflict_indicators_markers.gpkg"
metadata <- read_sf(src, layer = "metadata")
indicators <- read_sf(src, layer = "indicators")

# complete the indicator table to contain all combinations filled with 0
indicators <- select(indicators, -indicator) %>%
  mutate(
    datetime = as.character(format(datetime, "%Y"))
  ) %>%
  # this should not be necessary - FIXME in mapme.biodiversity
  distinct(assetid, datetime, variable, unit, .keep_all = TRUE) %>%
  filter(grepl("^fatalities_*|^exposed_*|^population_", variable))

indicators <- complete(indicators, assetid, nesting(datetime, variable), fill = list(value = 0, unit = "count"))

# calculate shares for the total variables
indicators <- indicators %>%
  filter(grepl("*total*|*_sum$", variable)) %>%
  pivot_wider(
    id_cols = c(assetid, datetime, unit),
    names_from = variable,
    values_from = value) %>%
  fill(population_sum, .direction = "down") %>%
  mutate(
    across(ends_with("total"), ~ .x / population_sum)
  ) %>%
  pivot_longer(
    cols = ends_with("total"),
    names_to = "variable",
  ) %>%
  mutate(
    variable = gsub("_total$", "_share", variable),
    value = ifelse(is.infinite(value)|is.nan(value), 0, value),
    value = ifelse(grepl("*_share$", variable), value * 1000, value),
    unit = ifelse(grepl("*_share$", variable), "per 100,000 inhabitants", unit)
    )  %>%
  select(assetid, datetime, unit, variable, value) %>%
  bind_rows(indicators) %>%
  arrange(assetid, datetime)


# attach indicator table to centroids of the adm units
centroids <- st_centroid(metadata)
centroids <- full_join(centroids, indicators, by = "assetid")

# attach the total and share variables in wide format to the adm units
indicators_totals <- indicators %>%
  filter(grepl('_total$|_share$|^population_sum$', variable)) %>%
  arrange(assetid, datetime) %>%
  select(-unit) %>%
  pivot_wider(
    id_cols = assetid,
    names_from = c(variable, datetime)
  ) %>%
  right_join(metadata, by = "assetid") %>%
  st_as_sf()

# write output
write_sf(centroids, "output/adm2_points_conflict_indicators_markers_long.gpkg", delete_dsn = TRUE)
write_sf(indicators_totals, "output/adm2_polygons_conflict_indicators_markers_wide.gpkg", delete_dsn = TRUE)
