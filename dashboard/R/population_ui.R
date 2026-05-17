population_tab_ui <- function() {
  tabPanel(
    "Population",
    sidebarLayout(
      sidebarPanel(
        h4("Population Controls"),
        radioButtons(
          "taxa_level",
          "Taxonomic Level",
          choices = c("Phylum", "Family", "Species", "Genus"),
          selected = "Phylum"
        ),
        selectInput(
          "group_filter",
          "Study Group",
          choices = c("Active IBD", "Quiescent", "Non-IBD")
        ),
        sliderInput(
          "top_n",
          "Number of Taxa to Display",
          min = 5,
          max = 15,
          value = 10
        )
      ),
      mainPanel(
        fluidRow(
          column(
            width = 6,
            wellPanel(
              h4("Population Summary"),
              uiOutput("population_summary")
            )
          ),
          column(
            width = 6,
            wellPanel(
              h4("Dietary Summary"),
              uiOutput("diet_summary")
            )
          ),
          column(
            width = 12,
            wellPanel(
              h4("Normalized Population Abundance"),
              plotOutput("population_plot", height = "600px")
            )
          ),
          column(
            width = 12,
            wellPanel(
              h4("Diet Comparison"),
              selectInput(
                "diet_variable",
                "Select Dietary Measure",
                choices = c(
                  "Calories" = "Cals..kcal.",
                  "Protein" = "Prot..g.",
                  "Carbohydrates" = "Carb..g.",
                  "Sugar" = "Sugar..g.",
                  "Saturated Fat" = "SatFat..g.",
                  "Monounsaturated Fat" = "MonoFat..g.",
                  "Polyunsaturated Fat" = "PolyFat..g.",
                  "Trans Fat" = "TransFat..g.",
                  "Fiber" = "TotFib..g."
                ),
                selected = "cals_kcal"
              ),
              plotOutput("diet_plot", height = "600px")
            )
          )
        )
      )
    )
  )
}
