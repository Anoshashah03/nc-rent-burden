# NC Rent Burden Explorer

Live app: https://anoshashah.shinyapps.io/nc-rent-burden/

I built this to see where renters in North Carolina are paying the most of their income on rent, and whether college-town counties look different from the rest of the state. It's an R Shiny app built on Census data, covering all 100 counties from 2015 to 2022.

## What's in the app

- **Map:** every NC county colored by one of four measures, with a year slider.
- **County Detail:** one county's trend over time, plus a top 15 ranking for the chosen year.
- **College Towns:** Orange (UNC), Durham (Duke, NCCU), Watauga (App State), Pitt (ECU) and Guilford (UNCG, NC A&T) compared to the NC county median.

The four measures are median rent as a share of income, the % of renters paying 30% or more of income on rent, the % paying 50% or more, and how many full-time minimum-wage jobs it would take to afford the median rent without going over 30% of income.

## What I found

All numbers below are from the 2022 release, which covers 2018 to 2022.

- Watauga County stands out the most. The median renter there spends 45.7% of income on rent, compared to 28.8% for the median NC county.
- In Watauga, 66% of renters pay 30% or more of their income on rent, and 46.8% pay half or more. The median NC county is 47.3% and 22.8%.
- In Orange County, 54.1% of renters pay 30% or more of their income on rent, and 32.7% pay 50% or more. I checked these two against the raw Census table (B25070) and they matched.
- Affording the median rent in Orange County would take about 3.5 full-time minimum-wage jobs.
- Of the five college-town counties, Watauga and Orange are well above the state median on both burden measures. Pitt is a few points above on the 50% measure, Guilford is about at the median, and Durham is slightly below.

## Data

American Community Survey 5-year estimates from the U.S. Census Bureau, pulled with the tidycensus package:

- B25071: median gross rent as a percentage of household income
- B25070: renters by rent-burden bracket
- B25064: median gross rent in dollars
- B19013: median household income

County boundaries are from Census TIGER/Line files through the tigris package.

## How I calculated things

- Cost-burdened means paying 30% or more of income on rent, and severely burdened means 50% or more. I left out renter households where the Census couldn't compute the ratio, so they don't pull the percentages down.
- Margins of error on the burden percentages come from moe_prop() in tidycensus.
- For reliability, I calculated the coefficient of variation on each county's median rent-burden estimate. If it's above 30%, the county is outlined in red on the map.
- The minimum-wage measure uses the federal minimum of $7.25, which is what NC has had the whole time.
- The minimum-wage measure only uses rent prices, not income, so it can tell a different story from the burden percentages.
- The data script stops with an error if it doesn't get all 100 counties for all 8 years.

## Limitations

- Each 5-year estimate overlaps with the next one, so comparing 2021 to 2022 isn't really fair. Years at least five apart, like 2017 and 2022, are better.
- Students probably push the college-town numbers up. A full-time student might report little income while paying rent with loans or help from family, so the numbers can look worse than real hardship. I think this likely affects Watauga and Orange, but I haven't tested it.
- Small counties like Hyde and Tyrrell have small samples and wide margins of error. The red outline only reflects the median rent-burden estimate, not the other three measures.
- The "NC county median" is the median of the 100 county values. It is not a population-weighted statewide number.
- This only describes what the data shows. It doesn't explain why burden differs between counties.

## Run it yourself

1. Install the packages: `install.packages(c("shiny", "tidyverse", "tidycensus", "tigris", "sf", "leaflet"))`
2. Get a free Census API key at https://api.census.gov/data/key_signup.html and save it with `census_api_key("YOUR_KEY", install = TRUE)`.
3. Run `get_data.R` to make `rent.rds`, then `prep_map_data.R` to make `nc_counties.rds`.
4. Run `shiny::runApp()` from the project folder.

## Files

- `get_data.R`: pulls and cleans the Census data
- `prep_map_data.R`: downloads the county boundaries
- `app.R`: the Shiny app
- `rent.rds` and `nc_counties.rds`: saved data the app reads

## About me

Anosha Shah, UNC Chapel Hill, B.S. in Information Science with a minors in Data Science and Middle East and Islamic Studies