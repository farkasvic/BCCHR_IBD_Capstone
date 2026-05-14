library(shiny)
library(ggplot2)
library(plotly)
library(dplyr)
library(tidyr)
library(readxl)

# Separate diet and taxa datasets and remove taxa tags from column names
diet <- read_excel("../data/processed/dietary_cleaned.xlsx")

phylum <- read.csv("../data/processed/phylum.csv")
names(phylum) <- sub("^p__", "", names(phylum))

family <- read.csv("../data/processed/family.csv")
names(family) <- sub("^f__", "", names(family))

species <- read.csv("../data/processed/species.csv")
names(species) <- sub("^s__", "", names(species))

genus <- read.csv("../data/processed/genus.csv")
names(genus) <- sub("^g__", "", names(genus))

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
                    h4("Participant vs Canadian Food Guide"),
                    uiOutput("cfg_card")
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
             
             # Population control panel
             sidebarPanel(
               h4("Population Controls"),
               
               # Toggle between taxa data
               radioButtons(
                 "taxa_level",
                 "Taxonomic Level",
                 choices = c("Phylum", "Family", "Species", "Genus"),
                 selected = "Phylum"
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
               fluidRow(
                 
                 # Population summary statistics
                 column(
                   width = 6,
                   wellPanel(
                     h4("Population Summary"),
                     uiOutput("population_summary")
                   )
                 ),
                 
                 # Population dietary statistics
                 column(
                   width = 6,
                   wellPanel(
                     h4("Dietary Summary"),
                     uiOutput("diet_summary")
                   )
                 ),
                 
                 # Fungal abundance plot
                 column(
                   width = 12,
                   wellPanel(
                     h4("Normalized Population Abundance"),
                     plotOutput("population_plot", height = "600px")
                   )
                 ),
                 
                 # Diet comparison plot
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
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output, session) {
  score_columns <- c(
    "MPGrain..oz.eq.",
    "MPVeg..c.eq.",
    "MPFruit..c.eq.",
    "MPDairy..c.eq.",
    "MPProt..oz.eq.",
    "TotFib..g."
  )
  
  cfg_targets <- c(
    "MPGrain..oz.eq." = 5.0,
    "MPVeg..c.eq." = 2.5,
    "MPFruit..c.eq." = 2.0,
    "MPDairy..c.eq." = 2.0,
    "MPProt..oz.eq." = 5.5,
    "TotFib..g." = 28.0
  )

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
    
    microbiome_data <- if (input$individual_taxa_level == "Species") species else genus
    taxon_cols <- setdiff(
      names(microbiome_data),
      c("Sample_ID", "Participant_ID", "Sample_type", "Study_group_new", "Fiber_restriction")
    )
    
    selected_rows <- microbiome_data %>%
      filter(toupper(Participant_ID) == selected_id)
    
    validate(need(nrow(selected_rows) > 0, "No microbiome data found for this participant."))
    validate(need(length(taxon_cols) > 0, "No taxonomic columns found."))
    
    pie_df <- selected_rows %>%
      summarise(across(all_of(taxon_cols), ~ mean(.x, na.rm = TRUE))) %>%
      pivot_longer(
        cols = everything(),
        names_to = "Taxon",
        values_to = "Abundance"
      ) %>%
      filter(!is.na(Abundance), Abundance > 0) %>%
      arrange(desc(Abundance))
    
    validate(need(nrow(pie_df) > 0, "No microbiome composition available."))
    
    pie_df <- pie_df %>%
      mutate(
        Taxon = ifelse(Taxon == "NA", "Unclassified", Taxon)
      )
    
    if (nrow(pie_df) > 5) {
      pie_df <- bind_rows(
        pie_df[1:5, ],
        data.frame(
          Taxon = "Other",
          Abundance = sum(pie_df$Abundance[-(1:5)])
        )
      )
    }
    
    plot_ly(
      data = pie_df,
      labels = ~Taxon,
      values = ~Abundance,
      type = "pie",
      height = 260,
      textinfo = "none",
      hovertemplate = paste(
        "<b>%{label}</b><br>",
        "Proportion: %{percent}<extra></extra>"
      )
    ) %>%
      layout(
        showlegend = TRUE,
        margin = list(l = 20, r = 20, t = 20, b = 20),
        legend = list(
          orientation = "h",
          x = 0.5,
          y = -0.15,
          xanchor = "center",
          yanchor = "top"
        )
      )
  })
  
  output$cfg_card <- renderUI({
    req(input$search_id)
    
    selected_id <- toupper(trimws(input$search_id))
    selected_rows <- participant_data %>%
      filter(toupper(participant_id) == selected_id)
    
    validate(need(nrow(selected_rows) > 0, "No participant found."))
    
    participant_summary <- selected_rows %>%
      mutate(across(all_of(score_columns), ~ as.numeric(.x))) %>%
      summarise(across(all_of(score_columns), ~ mean(.x, na.rm = TRUE)))
    
    intake_values <- unlist(participant_summary[1, score_columns], use.names = FALSE)
    names(intake_values) <- score_columns
    pct_reached <- round((intake_values / cfg_targets[score_columns]) * 100, 0)
    pct_reached[!is.finite(pct_reached)] <- NA
    met_target <- intake_values >= cfg_targets[score_columns]
    summary_score <- sum(met_target, na.rm = TRUE)
    
    display_names <- c(
      "MPGrain..oz.eq." = "Grains",
      "MPVeg..c.eq." = "Vegetables",
      "MPFruit..c.eq." = "Fruit",
      "MPDairy..c.eq." = "Dairy",
      "MPProt..oz.eq." = "Protein",
      "TotFib..g." = "Fibre"
    )
    
    rows <- lapply(score_columns, function(col) {
      current_met <- unname(met_target[col])
      status_text <- if (isTRUE(current_met)) "On target" else "Below target"
      status_color <- if (isTRUE(current_met)) "#2E8B57" else "#C0392B"
      
      tags$tr(
        tags$td(display_names[col], style = "padding:6px 10px;"),
        tags$td(sprintf("%.2f", intake_values[col]), style = "padding:6px 10px; text-align:right;"),
        tags$td(sprintf("%.2f", cfg_targets[col]), style = "padding:6px 10px; text-align:right;"),
        tags$td(
          ifelse(is.na(pct_reached[col]), "NA", paste0(pct_reached[col], "%")),
          style = "padding:6px 10px; text-align:right;"
        ),
        tags$td(
          status_text,
          style = paste0("padding:6px 10px; font-weight:bold; color:", status_color, ";")
        )
      )
    })
    
    tagList(
      tags$p(
        tags$b("Summary Score: "),
        paste0(summary_score, " / ", length(score_columns), " targets met"),
        style = "font-size:16px;"
      ),
      tags$table(
        style = "width:100%; font-size:13px; border-collapse:collapse;",
        tags$thead(
          tags$tr(
            tags$th("Food Group", style = "padding:6px 10px; text-align:left; border-bottom:1px solid #ddd;"),
            tags$th("Intake", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("Target", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("% Target", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("Status", style = "padding:6px 10px; text-align:left; border-bottom:1px solid #ddd;")
          )
        ),
        tags$tbody(rows)
      )
    )
  })
  
  # -----------------------------
  # Population Logic
  # -----------------------------
  
  # Select taxa data based on user choice
  selected_data <- reactive({
    if (input$taxa_level == "Phylum") {
      phylum
    } else if (input$taxa_level == "Family") {
      family
    } else if (input$taxa_level == "Species") {
      species
    } else {
      genus
    }
  })
  
  # Filter selected data by study group
  filtered_data <- reactive({
    data <- selected_data()
    
    data |>
      filter(Study_group_new == input$group_filter)
  })
  
  # Data summary
  output$population_summary <- renderUI({
    
    data <- filtered_data()
    
    tagList(
      tags$p(tags$b("Taxonomic Level: "), input$taxa_level),
      tags$p(tags$b("Group: "), input$group_filter),
      tags$p(tags$b("Number of Samples: "), nrow(data)),
      tags$p(tags$b("Number of Taxa: "), ncol(data) - 4) # 4 is the number of non-taxa columns
    )
  })
  
  # Filter by study group
  participants_filtered <- reactive({
    participant_data |>
      filter(Study_group_new == input$group_filter)
  })
  
  # Dietary Summary
  output$diet_summary <- renderUI({
    
    data <- participants_filtered()
    
    mean_cals <- round(mean(data$Cals..kcal., na.rm = TRUE), 1)
    mean_protein <- round(mean(data$Prot..g., na.rm = TRUE), 1)
    mean_carbs <- round(mean(data$Carb..g., na.rm = TRUE), 1)
    mean_sugar <- round(mean(data$Sugar..g., na.rm = TRUE), 1)
    mean_satfat <- round(mean(data$SatFat..g., na.rm = TRUE), 1)
    mean_monofat <- round(mean(data$MonoFat..g., na.rm = TRUE), 1)
    mean_polyfat <- round(mean(data$PolyFat..g., na.rm = TRUE), 1)
    mean_transfat <- round(mean(data$TransFat..g., na.rm = TRUE), 1)
    mean_fiber <- round(mean(data$TotFib..g., na.rm = TRUE), 1)
    
    tagList(
      tags$p(tags$b("Mean Calories: "), mean_cals),
      tags$p(tags$b("Mean Protein: "), mean_protein),
      tags$p(tags$b("Mean Carbohydrates: "), mean_carbs),
      tags$p(tags$b("Mean Sugar: "), mean_sugar),
      tags$p(tags$b("Mean Saturated Fat: "), mean_satfat),
      tags$p(tags$b("Mean Monounsaturated Fat: "), mean_monofat),
      tags$p(tags$b("Mean Polyunsaturated Fat: "), mean_polyfat),
      tags$p(tags$b("Mean Trans Fat: "), mean_transfat),
      tags$p(tags$b("Mean Fiber: "), mean_fiber)
    )
  })
  
  # Create group diet comp plot
  output$diet_plot <- renderPlot({
    
    # 
    summary_data <- participant_data |>
      group_by(Study_group_new) |>
      summarise(
        MeanValue = mean(
          .data[[input$diet_variable]],
          na.rm = TRUE
        )
      )
    
    # Plot
    ggplot(
      summary_data,
      aes(
        x = Study_group_new,
        y = MeanValue,
        fill = Study_group_new
      )
    ) +
      geom_col(width = 0.7) +
      labs(
        title = paste(
          "Mean",
          input$diet_variable,
          "Intake by Study Group"
        ),
        x = "Study Group",
        y = "Mean Intake"
      ) +
      theme_minimal() +
      theme(
        legend.position = "none",
        axis.text.x = element_text(angle = 20, hjust = 1)
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
