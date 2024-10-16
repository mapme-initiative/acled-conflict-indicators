library(sf)
library(dplyr)
library(tidyr)
library(tibble)
library(future)
library(furrr)
library(openxlsx2)
library(mapme.biodiversity)

indicators_gpkg <- "output/adm2_polygons_conflict_indicators.gpkg"
projects_locs_json <- "data/project_locations.json"
projects_info_xlsx <- "data/Kopie von Portfolio_Vorhaben.xlsx"

(indicators <- read_portfolio(indicators_gpkg))
(projects_locs <- read_sf(projects_locs_json))
(projects_info <- read_xlsx(projects_info_xlsx, start_row = 6))

# exclude project locations outside -180 | 180
coords <- st_coordinates(projects_locs)
index <- which(coords[ ,1] < -180 | coords[ ,1] > 180)
projects_locs <- projects_locs[-index, ]

# subset projects_info to include the desired markers
names(projects_info) <- gsub("\\n", "", gsub("\\.", "", gsub(" ", "_", tolower(names(projects_info)))))
crs_cols <- which(startsWith(names(projects_info), "crs"))
names(projects_info)[crs_cols] <- paste0(names(projects_info)[crs_cols], "_", 1:2)
projects_info <- as_tibble(projects_info)

# re-code markers
markers <- select(
  projects_info,
  project_nr = projektnummer,
  oecd_fragility = "oecd-fragilität",
  peace_and_security = frieden_undsicherheit,
  refugees_flight = "flüchtlinge/flucht") %>%
  filter(!is.na(project_nr)) %>%

  mutate(

    oecd_fragility = case_when(
      oecd_fragility == "nicht fragil" ~ 0,
      oecd_fragility == "fragil" ~ 1,
      oecd_fragility == "extrem fragil" ~ 2,
      is.na(oecd_fragility) ~ NA
    ),

    peace_and_security = case_when(
      peace_and_security == "FS: 0" ~ 0,
      peace_and_security == "FS: 1" ~ 1,
      peace_and_security == "FS: 2" ~ 2,
      is.na(peace_and_security) ~ NA
    ),

    refugees_flight = case_when(
      refugees_flight == "Nein" ~ 0,
      refugees_flight == "1 % - 25 %" ~ 25,
      refugees_flight == "26 % - 50 %" ~ 50,
      refugees_flight == "51 % - 75 %" ~ 75,
      refugees_flight == "76 % - 100 %" ~ 100,
      is.na(refugees_flight) ~ NA
    )) %>%
  mutate_all(as.integer) %>%
  group_by(project_nr) %>%
  summarise_all(max, na.rm = TRUE)

is.na(markers) <- sapply(markers, is.infinite)

# join project locations with markers
projects_locs <- left_join(
  projects_locs, markers,
  by = c("n_projet_kfw_inpro" = "project_nr"))

# add markers to adm units

# first, add adm identifier to the locations
is_within <- st_within(projects_locs, indicators, prepared = TRUE)
is_within2 <- is_within
is.na(is_within2) <- lengths(is_within2) == 0
is_within2[lengths(is_within2) == 2] <- lapply(is_within2[lengths(is_within2) == 2], function(y) y[[1]])
is_within2 <- unlist(is_within2)
projects_locs$adm2_id <- indicators$adm2_id[is_within2]

# second, summarise the markers per adm unit with project locations
adm_markers <- select(
  st_drop_geometry(projects_locs),
  adm2_id,
  oecd_fragility,
  peace_and_security,
  refugees_flight) %>%
  group_by(adm2_id) %>%
  summarise_all(max, na.rm = TRUE)

is.na(adm_markers) <- sapply(adm_markers, is.infinite)

# third, join the marker info with the original adm units
indicators <- left_join(indicators, adm_markers, by = "adm2_id")

# now we write the output
write_portfolio(indicators, "output/adm2_polygons_conflict_indicators_markers.gpkg")
write_sf(projects_locs, "output/project_locations_markers.gpkg", delete_dsn = TRUE)
