individual_server <- function(input, output, session) {
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
      fluidRow(
        column(
          width = 6,
          tags$p(tags$b("ID: "), result$ID[1]),
          tags$p(tags$b("Age: "), result$Age[1]),
          tags$p(tags$b("Sex: "), result$Sex[1]),
          tags$p(tags$b("Ethnicity: "), result$Ethnicity[1]),
          tags$p(tags$b("Country of Origin: "), result$Country_of_Origin[1]),
          tags$p(tags$b("Years Living in Canada: "), result$Years_Living_in_Canada[1]),
          tags$p(tags$b("Weight (lbs): "), result$Weight_lbs[1])
        ),
        column(
          width = 6,
          tags$p(tags$b("Height (cm): "), result$Height_cm[1]),
          tags$p(tags$b("Exercise History: "), result$Exercise_History[1]),
          tags$p(tags$b("Comorbidities: "), result$Comorbidities[1]),
          tags$p(tags$b("Family History of IBD: "), result$Family_History_of_IBD[1]),
          tags$p(tags$b("Smoking Status: "), result$Smoking_Status[1]),
          tags$p(tags$b("Alcohol Intake: "), result$Alcohol_Intake[1]),
          tags$p(tags$b("Prebiotics: "), format_prevalence(result$Prebiotics[1])),
          tags$p(tags$b("Probiotics: "), format_prevalence(result$Probiotics[1]))
        )
      )
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
      arrange(desc(Abundance)) %>%
      mutate(Taxon = ifelse(Taxon == "NA", "Unclassified", Taxon))

    validate(need(nrow(pie_df) > 0, "No microbiome composition available."))

    if (nrow(pie_df) > 5) {
      pie_df <- bind_rows(
        pie_df[1:5, ],
        data.frame(
          Taxon = "Other",
          Abundance = sum(pie_df$Abundance[-(1:5)])
        )
      )
    }

    build_microbiome_pie(pie_df)
  })

  output$disease_activity_card <- renderUI({
    result <- participant_match()
    if (nrow(result) == 0) {
      return(tags$p("No participant found."))
    }

    tagList(
      tags$p(tags$b("Harvey Bradshaw Index: "), format_missing(result$Harvey_Bradshaw_Index[1])),
      tags$p(tags$b("General Well-Being: "), format_missing(result$General_Well_Being[1])),
      tags$p(tags$b("Abdominal Pain: "), format_missing(result$Abdominal_Pain[1])),
      tags$p(tags$b("Daily Soft Stools: "), format_missing(result$Daily_Soft_Stools[1])),
      tags$p(tags$b("Advanced Therapy Changes: "), format_missing(result$Advanced_Therapy_Changes[1]))
    )
  })

  output$symptom_burden_card <- renderUI({
    result <- participant_match()
    if (nrow(result) == 0) {
      return(tags$p("No participant found."))
    }

    tagList(
      tags$p(tags$b("Fatigue: "), format_missing(result$Fatigue_Frequency[1])),
      tags$p(tags$b("Anxiety: "), format_missing(result$Anxiety_Frequency[1])),
      tags$p(tags$b("Sleep Difficulty: "), format_missing(result$Sleep_Difficulty_Frequency[1])),
      tags$p(tags$b("Abdominal Bloating: "), format_missing(result$Abdominal_Bloating_Frequency[1])),
      tags$p(tags$b("Rectal Bleeding: "), format_missing(result$Rectal_Bleeding_Frequency[1])),
      tags$p(tags$b("Feeling Unwell: "), format_missing(result$Feeling_Unwell_Frequency[1]))
    )
  })

  output$food_avoidance_card <- renderUI({
    result <- participant_match()
    if (nrow(result) == 0) {
      return(tags$p("No participant found."))
    }

    food_categories <- data.frame(
      Category = c(
        "Fruit",
        "Vegetables",
        "Whole grains",
        "Nuts / seeds",
        "Lactose",
        "Gluten",
        "Spicy foods",
        "High-fat foods"
      ),
      Active = c(
        format_avoidance_detail(result$Fruit_Avoidance_Active[1], result$Excluded_Fruits_Active[1]),
        format_avoidance_detail(result$Vegetable_Avoidance_Active[1], result$Excluded_Vegetables_Active[1]),
        format_avoidance_detail(result$Whole_Grain_Avoidance_Active[1], result$Excluded_Whole_Grains_Active[1]),
        format_avoidance_detail(result$Nut_Seed_Avoidance_Active[1], result$Excluded_Nuts_Seeds_Active[1]),
        format_avoidance_detail(result$Lactose_Avoidance_Active[1], result$Excluded_Lactose_Active[1]),
        format_avoidance_detail(result$Gluten_Avoidance_Active[1], result$Excluded_Gluten_Active[1]),
        format_avoidance_detail(result$Spicy_Food_Avoidance_Active[1], result$Excluded_Spicy_Foods_Active[1]),
        format_avoidance_detail(result$Fat_Food_Avoidance_Active[1], result$Excluded_Fat_Foods_Active[1])
      ),
      Remission = c(
        format_avoidance_detail(result$Fruit_Avoidance_Remission[1], result$Excluded_Fruits_Remission[1]),
        format_avoidance_detail(result$Vegetable_Avoidance_Remission[1], result$Excluded_Vegetables_Remission[1]),
        format_avoidance_detail(result$Whole_Grain_Avoidance_Remission[1], result$Excluded_Whole_Grains_Remission[1]),
        format_avoidance_detail(result$Nut_Seed_Avoidance_Remission[1], result$Excluded_Nuts_Seeds_Remission[1]),
        format_avoidance_detail(result$Lactose_Avoidance_Remission[1], result$Excluded_Lactose_Remission[1]),
        format_avoidance_detail(result$Gluten_Avoidance_Remission[1], result$Excluded_Gluten_Remission[1]),
        format_avoidance_detail(result$Spicy_Food_Avoidance_Remission[1], result$Excluded_Spicy_Foods_Remission[1]),
        format_avoidance_detail(result$Fat_Food_Avoidance_Remission[1], result$Excluded_Fat_Foods_Remission[1])
      ),
      stringsAsFactors = FALSE
    )

    rows <- lapply(seq_len(nrow(food_categories)), function(i) {
      tags$tr(
        tags$td(food_categories$Category[i], style = "padding:6px 10px; vertical-align:top;"),
        tags$td(food_categories$Active[i], style = "padding:6px 10px; vertical-align:top;"),
        tags$td(food_categories$Remission[i], style = "padding:6px 10px; vertical-align:top;")
      )
    })

    tags$table(
      style = "width:100%; font-size:13px; border-collapse:collapse;",
      tags$thead(
        tags$tr(
          tags$th("Category", style = "padding:6px 10px; text-align:left; border-bottom:1px solid #ddd;"),
          tags$th("Active Disease", style = "padding:6px 10px; text-align:left; border-bottom:1px solid #ddd;"),
          tags$th("Remission", style = "padding:6px 10px; text-align:left; border-bottom:1px solid #ddd;")
        )
      ),
      tags$tbody(rows)
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

    cohort_summary <- participant_data %>%
      mutate(across(all_of(score_columns), ~ as.numeric(.x))) %>%
      summarise(across(all_of(score_columns), ~ mean(.x, na.rm = TRUE)))

    fibre_target <- get_fibre_target(selected_rows$gender[1])
    participant_targets <- c(
      cfg_targets,
      "TotFib..g." = fibre_target
    )

    intake_values <- unlist(participant_summary[1, score_columns], use.names = FALSE)
    names(intake_values) <- score_columns
    cohort_average_values <- unlist(cohort_summary[1, score_columns], use.names = FALSE)
    names(cohort_average_values) <- score_columns
    pct_reached <- round((intake_values / participant_targets[score_columns]) * 100, 0)
    pct_reached[!is.finite(pct_reached)] <- NA
    met_target <- intake_values >= participant_targets[score_columns]
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
        tags$td(sprintf("%.2f", cohort_average_values[col]), style = "padding:6px 10px; text-align:right;"),
        tags$td(
          ifelse(is.na(participant_targets[col]), "NA", sprintf("%.2f", participant_targets[col])),
          style = "padding:6px 10px; text-align:right;"
        ),
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
            tags$th("Participant", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("Average", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("Target", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("% Target", style = "padding:6px 10px; text-align:right; border-bottom:1px solid #ddd;"),
            tags$th("Status", style = "padding:6px 10px; text-align:left; border-bottom:1px solid #ddd;")
          )
        ),
        tags$tbody(rows)
      )
    )
  })
}
