population_server <- function(input, output, session) {
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

  filtered_data <- reactive({
    data <- selected_data()

    data |>
      filter(Study_group_new == input$group_filter)
  })

  output$population_summary <- renderUI({
    data <- filtered_data()

    tagList(
      tags$p(tags$b("Taxonomic Level: "), input$taxa_level),
      tags$p(tags$b("Group: "), input$group_filter),
      tags$p(tags$b("Number of Samples: "), nrow(data)),
      tags$p(tags$b("Number of Taxa: "), ncol(data) - 4)
    )
  })

  participants_filtered <- reactive({
    participant_data |>
      filter(Study_group_new == input$group_filter)
  })

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

  output$diet_plot <- renderPlot({
    summary_data <- participant_data |>
      group_by(Study_group_new) |>
      summarise(
        MeanValue = mean(
          .data[[input$diet_variable]],
          na.rm = TRUE
        )
      )

    build_diet_plot(summary_data, input$diet_variable)
  })

  output$population_plot <- renderPlot({
    data <- filtered_data()

    summary_data <- data |>
      select(-c(Sample_ID, Participant_ID, Study_group_new, Fiber_restriction)) |>
      summarise(across(everything(), mean, na.rm = TRUE)) |>
      pivot_longer(
        cols = everything(),
        names_to = "taxon",
        values_to = "mean_abundance"
      ) |>
      arrange(desc(mean_abundance)) |>
      slice_head(n = input$top_n)

    build_population_plot(summary_data, input$taxa_level, input$group_filter)
  })
}
