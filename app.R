# ==============================================================
#  NC Rent Burden Explorer
# --------------------------------------------------------------
#  Author:   Anosha Shah
#  Purpose:  Let anyone explore where North Carolina renters
#            spend the most on rent, county by county.
#  Source:   U.S. Census Bureau, ACS 5-year estimates
#  Script:   Shiny app (reads rent.rds and nc_counties.rds)
# ==============================================================

library(shiny)
library(tidyverse)
library(leaflet)
library(sf)

# Data was prepared in get_data.R and prep_map_data.R,
# so the app never touches the Census API
rent        <- readRDS("rent.rds")
nc_counties <- readRDS("nc_counties.rds")

# Measures the user can switch between (label = column name)
measures <- c(
  "Median rent as % of income"                        = "median_rent_pct",
  "% of renters paying 30%+ of income"                = "burdened_pct",
  "% of renters paying 50%+ of income"                = "severe_pct",
  "Full-time minimum-wage jobs needed to afford rent" = "min_wage_jobs"
)

# Counties that host large universities
college_counties <- c("Orange", "Durham", "Watauga", "Pitt", "Guilford")


# ---- User interface ------------------------------------------
ui <- fluidPage(
  titlePanel("NC Rent Burden Explorer"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("measure", "Measure:", choices = measures),
      sliderInput("year", "Year (end of 5-year period):",
                  min = 2015, max = 2022, value = 2022, step = 1, sep = ""),
      selectInput("county", "County (for the County Detail tab):",
                  choices = sort(unique(rent$county)),
                  selected = "Orange"),
      helpText("Data: ACS 5-year estimates. Each year covers a 5-year",
               "window, so neighboring years overlap. For honest",
               "comparisons, look at years at least 5 apart."),
      helpText("On the map, counties outlined in red have a large",
               "margin of error, so treat them as approximate.")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Map",
                 leafletOutput("map", height = "560px")),
        tabPanel("County Detail",
                 textOutput("summary"),
                 uiOutput("warning"),
                 plotOutput("trend", height = "280px"),
                 plotOutput("ranking", height = "380px")),
        tabPanel("College Towns",
                 plotOutput("college", height = "420px"),
                 textOutput("college_note"))
      )
    )
  )
)


# ---- Server --------------------------------------------------
server <- function(input, output) {
  
  # Readable name of the chosen measure, used in labels
  measure_label <- reactive(names(measures)[measures == input$measure])
  
  # Row for the chosen county and year
  picked <- reactive({
    rent %>% filter(county == input$county, year == input$year)
  })
  
  # Map data: county shapes joined to that year's numbers by GEOID
  map_data <- reactive({
    nc_counties %>%
      left_join(filter(rent, year == input$year), by = "GEOID") %>%
      mutate(value = .data[[input$measure]],
             shaky = low_reliability %in% TRUE)
  })
  
  # ---- Map tab ----
  # No background tiles: the county shapes carry the whole story,
  # and free tile servers now ask for an API key.
  output$map <- renderLeaflet({
    d   <- map_data()
    pal <- colorNumeric("YlOrRd", domain = d$value, na.color = "#cccccc")
    
    leaflet(d) %>%
      htmlwidgets::onRender("function(el){ el.style.background = '#ffffff'; }") %>%
      addPolygons(
        fillColor   = ~pal(value),
        fillOpacity = 0.9,
        color       = ~ifelse(shaky, "#b30000", "white"),
        weight      = ~ifelse(shaky, 2.5, 0.7),
        label       = ~paste0(county, " County: ", value),
        highlightOptions = highlightOptions(weight = 3, color = "#333333",
                                            bringToFront = TRUE)
      ) %>%
      addLegend(pal = pal, values = ~value, title = measure_label(),
                position = "bottomright") %>%
      fitBounds(-84.4, 33.8, -75.4, 36.6)   # frame all of NC
  })
  
  # ---- County Detail tab ----
  output$summary <- renderText({
    p <- picked()
    paste0(input$county, " County (", input$year, "): ",
           p$burdened_pct, "% of renters pay 30%+ of their income on rent. ",
           "Affording the median rent would take about ", p$min_wage_jobs,
           " full-time minimum-wage jobs.")
  })
  
  # Warn when the Census estimate is unreliable (small sample)
  output$warning <- renderUI({
    if (isTRUE(picked()$low_reliability)) {
      p("Caution: this county's estimate has a large margin of error,",
        "so treat it as approximate.", style = "color: #b30000;")
    }
  })
  
  # One county over time
  output$trend <- renderPlot({
    rent %>%
      filter(county == input$county) %>%
      ggplot(aes(year, .data[[input$measure]])) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      labs(title = paste(input$county, "County over time"),
           x = NULL, y = measure_label()) +
      theme_minimal(base_size = 13)
  })
  
  # Top 15 counties for the chosen year and measure
  output$ranking <- renderPlot({
    rent %>%
      filter(year == input$year) %>%
      slice_max(.data[[input$measure]], n = 15) %>%
      ggplot(aes(reorder(county, .data[[input$measure]]),
                 .data[[input$measure]],
                 fill = county == input$county)) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      scale_fill_manual(values = c("grey70", "#1f6feb")) +
      labs(title = paste("Top 15 counties,", input$year),
           x = NULL, y = measure_label()) +
      theme_minimal(base_size = 13)
  })
  
  # ---- College Towns tab ----
  # Compare counties that host big universities against the
  # statewide median for the chosen year and measure.
  output$college <- renderPlot({
    d <- rent %>% filter(year == input$year)
    state_median <- median(d[[input$measure]], na.rm = TRUE)
    
    d %>%
      filter(county %in% college_counties) %>%
      ggplot(aes(reorder(county, .data[[input$measure]]),
                 .data[[input$measure]])) +
      geom_col(fill = "#1f6feb") +
      geom_hline(yintercept = state_median, linetype = "dashed") +
      annotate("text", x = 1, y = state_median,
               label = "NC county median", vjust = -0.6, hjust = 0,
               size = 4) +
      coord_flip() +
      labs(title = paste("College-town counties vs. the state,", input$year),
           x = NULL, y = measure_label()) +
      theme_minimal(base_size = 13)
  })
  
  output$college_note <- renderText({
    d <- rent %>% filter(year == input$year)
    state_median <- round(median(d[[input$measure]], na.rm = TRUE), 1)
    above <- d %>%
      filter(county %in% college_counties,
             .data[[input$measure]] > state_median) %>%
      nrow()
    paste0(above, " of the 5 college-town counties are above the NC county median (",
           state_median, ") for this measure.")
  })
}

shinyApp(ui, server)