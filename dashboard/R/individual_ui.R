individual_tab_ui <- function() {
  tabPanel(
    "Individual",
    sidebarLayout(
      sidebarPanel(
        width = 2,
        class = "control-sidebar",
        dashboard_card(
          "Search Participant",
          selectizeInput(
            "search_id",
            "Enter participant ID",
            choices = sort(unique(participants$ID)),
            selected = NULL,
            options = list(placeholder = "e.g. OPT_18")
          ),
          radioButtons(
            "individual_taxa_level",
            "Taxonomic Level",
            choices = c("Species", "Genus"),
            selected = "Genus"
          )
        )
      ),
      mainPanel(
        width = 10,
        fluidRow(
          class = "dashboard-row",
          column(
            width = 6,
            dashboard_card(
              "Participant Information",
              uiOutput("participant_info")
            )
          ),
          column(
            width = 3,
            dashboard_card(
              "Disease Activity",
              uiOutput("disease_activity_card")
            )
          ),
          column(
            width = 3,
            dashboard_card(
              "Symptom Burden",
              uiOutput("symptom_burden_card")
            )
          )
        ),
        fluidRow(
          class = "dashboard-row",
          column(
            width = 6,
            dashboard_card(
              "Participant vs Canadian Food Guide",
              uiOutput("cfg_card")
            )
          ),
          column(
            width = 6,
            dashboard_card(
              "Mycobiome Composition",
              plotlyOutput("microbiome_pie", height = "260px")
            )
          )
        ),
        fluidRow(
          class = "dashboard-row",
          column(
            width = 12,
            dashboard_card(
              "Food Avoidance",
              uiOutput("food_avoidance_card")
            )
          )
        )
      )
    )
  )
}
