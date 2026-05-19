source(file.path("R", "individual_ui.R"), local = TRUE)
source(file.path("R", "population_ui.R"), local = TRUE)

ui <- navbarPage(
  title = "IBD Dashboard",
  header = dashboard_head_tags(),
  individual_tab_ui(),
  population_tab_ui()
)
