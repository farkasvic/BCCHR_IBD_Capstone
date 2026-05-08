library(shiny)
library(ggplot2)
library(plotly)
library(dplyr)
library(tidyr)
library(readxl)

# Separate diet, species, and genus datasets
diet <- read_excel("../data/processed/dietary_cleaned.xlsx")
genus <- read.csv("../data/processed/genus.csv")
species <- read.csv("../data/processed/species.csv")

# merged characteristics_genus_species_dietary_inner.csv from processed file
participant_data <- read.csv(
  "../data/processed/characteristics_genus_species_dietary_inner.csv",
  stringsAsFactors = FALSE
)

participants <- participant_data %>%
  transmute(
    ID = participant_id,
    Age = age,
    Sex = gender,
    Ethnicity = ethnicity,
    Country_of_Origin = country_of_origin,
    Years_Living_in_Canada = years_living_in_canada,
    Weight_lbs = weight_.lbs.,
    Height_cm = height_.cm.,
    Exercise_History = exercise_history,
    Comorbidities = comorbidities,
    Family_History_of_IBD = family_history_of_ibd,
    Smoking_Status = smoking_status,
    Alcohol_Intake = alcohol_intake
  ) %>%
  distinct(ID, .keep_all = TRUE)

genus_cols <- grep("^g__", names(participant_data), value = TRUE)

# -----------------------------
# UI
# -----------------------------
ui <- navbarPage(
  title = "IBD Dashboard",
  
  # -----------------------------
  # Individual Page
  # -----------------------------
  tabPanel("Individual",
           sidebarLayout(
             sidebarPanel(
               h4("Search Participant"),
               textInput(
                 "search_id",
                 "Enter participant ID",
                 placeholder = "e.g. OPT_18"
               )
                  ),
            # 5 boxes in the main panel
            mainPanel(
              
              fluidRow(
                
                # Box 1
                column(
                  width = 6,
                  wellPanel(
                    h4("Participant Information"),
                    uiOutput("participant_info")
                  )
                ),
                
                # Box 2
                column(
                  width = 6,
                  wellPanel(
                    h4("Mycobiome Composition"),
                    plotlyOutput("microbiome_pie", height = "260px")
                  )
                )
              ),
              
              fluidRow(
                
                # Box 3
                column(
                  width = 6,
                  wellPanel(
                    h4("Box 3"),
                    p("Content goes here")
                  )
                ),
                
                # Box 4
                column(
                  width = 6,
                  wellPanel(
                    h4("Box 4"),
                    p("Content goes here")
                  )
                )
              ),
              
              fluidRow(
                
                # Box 5
                column(
                  width = 12,
                  wellPanel(
                    h4("Box 5"),
                    p("Content goes here")
                  )
                )
              )
            )
          )
        ),
  
  # -----------------------------
  # Population Page
  # -----------------------------
  tabPanel("Population",
           sidebarLayout(
             sidebarPanel(
               h4("Population Controls"),
               
               # Toggle between species and genus data
               radioButtons(
                 "taxa_level",
                 "Taxonomic Level",
                 choices = c("Species", "Genus"),
                 selected = "Species"
               ),
               
               # Toggle between IBD/Non-IBD groups
               selectInput(
                 "group_filter",
                 "Study Group",
                 choices = c("Active IBD", "Quiescent", "Non-IBD")
               ),
               
               # Number of taxa to display
               sliderInput(
                 "top_n",
                 "Number of Taxa to Display",
                 min = 5,
                 max = 15,
                 value = 10
               )
             ),
             mainPanel(
               verbatimTextOutput("population_summary"),
               h4("Normalized Population Abundance"),
               plotOutput("population_plot", height = "600px")
             )
           )
  )
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output, session) {

  # -----------------------------
  # Individual Logic
  # -----------------------------
  participant_match <- reactive({
    req(input$search_id)
    participants %>%
      filter(toupper(ID) == toupper(trimws(input$search_id)))
  })
  output$participant_info <- renderUI({
    result <- participant_match()
    if (nrow(result) == 0) {
      return(tags$p("No participant found."))
    }
    tagList(
      tags$p(tags$b("ID: "), result$ID[1]),
      tags$p(tags$b("Age: "), result$Age[1]),
      tags$p(tags$b("Sex: "), result$Sex[1]),
      tags$p(tags$b("Ethnicity: "), result$Ethnicity[1]),
      tags$p(tags$b("Country of Origin: "), result$Country_of_Origin[1]),
      tags$p(tags$b("Years Living in Canada: "), result$Years_Living_in_Canada[1]),
      tags$p(tags$b("Weight (lbs): "), result$Weight_lbs[1]),
      tags$p(tags$b("Height (cm): "), result$Height_cm[1]),
      tags$p(tags$b("Exercise History: "), result$Exercise_History[1]),
      tags$p(tags$b("Comorbidities: "), result$Comorbidities[1]),
      tags$p(tags$b("Family History of IBD: "), result$Family_History_of_IBD[1]),
      tags$p(tags$b("Smoking Status: "), result$Smoking_Status[1]),
      tags$p(tags$b("Alcohol Intake: "), result$Alcohol_Intake[1])
    )
  })
  output$microbiome_pie <- renderPlotly({
    req(input$search_id)
    selected_id <- toupper(trimws(input$search_id))
    selected_rows <- participant_data %>%
      filter(toupper(participant_id) == selected_id)
    validate(need(nrow(selected_rows) > 0, "No participant found."))
    validate(need(length(genus_cols) > 0, "No genus columns found."))
    
    pie_df <- selected_rows %>%
      summarise(across(all_of(genus_cols), ~ mean(.x, na.rm = TRUE))) %>%
      pivot_longer(
        cols = everything(),
        names_to = "Genus",
        values_to = "Abundance"
      ) %>%
      filter(!is.na(Abundance), Abundance > 0) %>%
      arrange(desc(Abundance))
    
    validate(need(nrow(pie_df) > 0, "No microbiome composition available."))
    
    pie_df <- pie_df %>%
      mutate(
        Genus = sub("^g__", "", Genus)
      )
    
    if (nrow(pie_df) > 5) {
      pie_df <- bind_rows(
        pie_df[1:5, ],
        data.frame(
          Genus = "Other",
          Abundance = sum(pie_df$Abundance[-(1:5)])
        )
      )
    }
    
    plot_ly(
      data = pie_df,
      labels = ~Genus,
      values = ~Abundance,
      type = "pie",
      textinfo = "none",
      hovertemplate = paste(
        "<b>%{label}</b><br>",
        "Proportion: %{percent}<extra></extra>"
      )
    ) %>%
      layout(
        showlegend = TRUE
      )
  })
  
  # -----------------------------
  # Population Logic
  # -----------------------------
  
  # Select data based on user choice
  selected_data <- reactive({
    if (input$taxa_level == "Species") {
      species
    } else {
      genus
    }
  })
  
  # Filter by study group
  filtered_data <- reactive({
    data <- selected_data()
    
    data |>
      filter(Study_group_new == input$group_filter)
  })
  
  # Data summary
  output$population_summary <- renderPrint({
    
    data <- filtered_data()
    
    # Count taxa columns (4 is the number of non-taxa columns)
    n_taxa <- ncol(data) - 4
    
    # Count samples
    n_samples <- nrow(data)
    
    # Mean total abundance per sample
    mean_total <- data |>
      select(-Group) |>
      rowSums(na.rm = TRUE) |>
      mean()
    
    cat(
      "Population Summary\n",
      "-------------------\n",
      "Taxonomic Level:", input$taxa_level, "\n",
      "Group:", input$group_filter, "\n",
      "Number of Samples:", n_samples, "\n",
      "Number of Taxa:", n_taxa, "\n",
      "Average Total Abundance:", round(mean_total, 2), "\n"
    )
    
  })
  
  # Create abundance plot
  output$population_plot <- renderPlot({
    data <- filtered_data()
    
    # Remove non-abundance columns before summarizing
    taxa_data <- data |>
      select(-c(Sample_ID, Participant_ID, Study_group_new, Fiber_restriction))
    
    # Compute mean abundance for each taxon
    summary_data <- taxa_data |>
      summarise(across(everything(), mean, na.rm = TRUE)) |>
      pivot_longer(
        cols = everything(),
        names_to = "taxon",
        values_to = "mean_abundance"
      ) |>
      arrange(desc(mean_abundance)) |>
      slice_head(n = input$top_n)
    
    # Plot
    ggplot(summary_data,
           aes(x = "", 
               y = mean_abundance,
               fill = taxon)) +
      geom_col(width = 1) +
      coord_polar(theta = "y") +
      labs(
        title = paste(input$taxa_level,
                      "Abundance -",
                      input$group_filter),
        fill = "Taxon"
      ) +
      theme_void()
  })
}

# -----------------------------
# Run App
# -----------------------------
shinyApp(ui = ui, server = server)
