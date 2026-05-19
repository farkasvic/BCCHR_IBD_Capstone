build_microbiome_pie <- function(pie_df) {
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
}

build_diet_plot <- function(summary_data, diet_variable) {
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
      title = paste("Mean", diet_variable, "Intake by Study Group"),
      x = "Study Group",
      y = "Mean Intake"
    ) +
    theme_minimal() +
    theme(
      legend.position = "none",
      axis.text.x = element_text(angle = 20, hjust = 1)
    )
}

build_population_plot <- function(summary_data, taxa_level, group_filter) {
  ggplot(
    summary_data,
    aes(
      x = "",
      y = mean_abundance,
      fill = taxon
    )
  ) +
    geom_col(width = 1) +
    coord_polar(theta = "y") +
    labs(
      title = paste(taxa_level, "Abundance -", group_filter),
      fill = "Taxon"
    ) +
    theme_void()
}
