ACLED Conflict Indicators
================
Darius A. Görgen
2024-10-16

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)

# Introduction

This repository contains the codes used to calculate local indicators of
conflict exposure. Conflict event data are taken from
[ACLED](https://acleddata.com/) and indicators are calculated based on
administrative units of level 2. Popluation data is based on
[WorldPop](https://www.worldpop.org/). Project informations represents
data internal to KfW. Since most of the used data cannot be shared
publicly, this repository only containes the code in order to reproduce
the results. The conflict indicators, however, can be calculated using
[`{mapme.biodiversity}`](https://mapme-initiative.github.io/mapme.biodiversity/reference/acled.html)
and a valid ACLED account with API access.

As indicators of local conflict exposure we calculate:

- total number of aggregated fatalities per unit and year
- number of fatalities per 100,000 inhabitants per unit and year
- total number of population exposed to certain types of events per unit
  and year
- number of people exposed to these events per 100,000 inhabitants per
  unit and year

based on the following configuration file which is used as input to
[`{mapme.pipelines}`](https://github.com/mapme-initiative/mapme.pipelines)

``` yaml
input: data/adm2_polygons.gpkg
output: output/adm2_polygons_conflict_indicators.gpkg
datadir: /home/rstudio/mapme/data
batchsize: 5000
options:
  overwrite: true
  maxcores: 10
  progress: true
  chunksize: NULL
resources:
  get_acled:
    args:
      years: [2019, 2020, 2021, 2022, 2023]
      accept_terms: TRUE
  get_worldpop:
    args:
      years: [2019]
indicators:
  calc_exposed_population_acled:
    args:
      distance: [5000, 2000, 5000, 3000]
      years: [2019, 2020, 2021, 2022, 2023]
      filter_category: event_type
      filter_types: [battles, riots, explosions/remote_violence, violence_against_civilians]
      precision_location: 1
      precision_time: 1
  calc_fatalities_acled:
    args:
      years: [2019, 2020, 2021, 2022, 2023]
      stratum: event_type
      precision_location: 1
      precision_time: 1
  calc_population_count:
    args:
      engine: exactextract
      stats: sum
```

To fetch ACLED data successfully, the code expects to find a file called
`.env` in the top-level with the following valid content to be set:

    ACLED_ACCESS_EMAIL=<your-email>
    ACLED_ACCESS_KEY=<your-key>
